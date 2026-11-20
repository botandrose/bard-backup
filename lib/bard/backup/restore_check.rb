require "backhoe"
require "tmpdir"
require "zlib"
require "active_support/hash_with_indifferent_access"
require "bard/backup/finder"

module Bard
  class Backup
    # Restores the latest database backup into a scratch database beside the live one, checks
    # that it holds real data, and drops it. Raises Failed with every problem found.
    class RestoreCheck < Struct.new(:destinations, :database, keyword_init: true)
      class Failed < StandardError; end

      def self.call(...)
        new(...).call
      end

      def call
        found = Finder.new(destinations).find
        backup = Bard::Backup.new(timestamp: found[:timestamp], destinations: [found[:destination].info])
        label = "#{backup.timestamp.iso8601} (#{found[:destination].info[:name]})"

        Dir.mktmpdir("bard-backup-restore-check-") do |dir|
          path = File.join(dir, File.basename(found[:filename]))
          File.binwrite(path, found[:destination].s3_tree.get(found[:filename]))
          scratch = ScratchDatabase.new(live_config, dir)

          fail! label, DumpIntegrity.new(path, scratch.database).problems
          row_counts = scratch.load(path)
          fail! label, sanity_problems(row_counts)
          Result.new(backup:, row_counts:)
        end
      end

      class Result < Data.define(:backup, :row_counts)
        def to_s
          "Restore check passed for backup #{backup.timestamp.iso8601}: #{row_counts.size} tables, #{row_counts.values.sum} rows"
        end
      end

      private

      def live_config
        ActiveSupport::HashWithIndifferentAccess.new(database || Backhoe::Database.new.config)
      end

      def fail!(label, problems)
        raise Failed, "Restore check failed for backup #{label}: #{problems.join("; ")}" if problems.any?
      end

      def sanity_problems(row_counts)
        return ["the restored database has no tables"] if row_counts.empty?
        problems = []
        problems << "schema_migrations is missing or empty" unless row_counts["schema_migrations"].to_i.positive?
        problems << "every table is empty" if row_counts.except("schema_migrations", "ar_internal_metadata").values.all?(&:zero?)
        problems
      end

      # Catches the corruption seen in production: zero-filled heads, CRC errors, another
      # project's gzip appended (which zcat and GzipReader silently ignore), and cut-short dumps.
      class DumpIntegrity < Struct.new(:path, :database)
        TAIL_BYTES = 64 * 1024

        def problems
          head, tail, trailing = read
          return ["the dump has #{trailing} unexpected bytes after its gzip stream"] if trailing.positive?
          return ["the dump is empty"] if head.empty?

          if database.mysql? && !tail.match?(/^-- Dump completed/)
            ['the MySQL dump has no "-- Dump completed" line, so it was cut short']
          elsif database.postgresql? && !tail.match?(/^-- PostgreSQL database dump complete/)
            ['the PostgreSQL dump has no "-- PostgreSQL database dump complete" line, so it was cut short']
          elsif database.sqlite? && !head.start_with?("SQLite format 3\0")
            ["the dump is not an SQLite database"]
          else
            []
          end
        rescue Zlib::Error => error
          ["the dump is not a valid gzip file: #{error.message}"]
        end

        private

        def read
          File.open(path, "rb") do |file|
            gzip = Zlib::GzipReader.new(file)
            head = gzip.read(16) || "".b
            tail = head.dup
            while (chunk = gzip.read(1024 * 1024))
              tail = (tail + chunk)[-TAIL_BYTES..] || tail + chunk
            end
            trailing = gzip.unused.to_s.bytesize + (file.size - file.pos)
            gzip.finish
            [head, tail, trailing]
          end
        end
      end

      class ScratchDatabase
        attr_reader :config, :database

        def initialize(live_config, dir)
          live = Backhoe::Database.new(live_config)
          name = live.sqlite? ? File.join(dir, "restore_check.sqlite3") : "#{live.name}_restore_check"
          @config = live_config.merge("database" => name)
          @database = Backhoe::Database.new(config)
        end

        def load(path)
          require "bard/backup/restore_check/scratch_record"
          if database.mysql?
            @binlog = with_server { |connection| connection.select_value("SELECT @@log_bin").to_i == 1 }
            with_server do |connection|
              connection.execute("DROP DATABASE IF EXISTS #{connection.quote_table_name(name)}")
              connection.execute("CREATE DATABASE #{connection.quote_table_name(name)}")
            end
            Backhoe::Load.new(database, unlogged(path), false).call
          else
            Backhoe::Load.new(database, path, true).call
          end
          row_counts
        ensure
          drop
        end

        private

        def name = config["database"]

        # A restored copy in the binary log would fill the disk for its retention period and replicate.
        def unlogged(path)
          return path unless @binlog
          File.join(File.dirname(path), "unlogged-#{File.basename(path)}").tap do |unlogged|
            File.open(unlogged, "wb") do |file|
              file.write(Zlib.gzip("SET SESSION sql_log_bin = 0;\n"))
              File.open(path, "rb") { |dump| IO.copy_stream(dump, file) }
            end
          end
        end

        def connection_config(overrides = {})
          hash = config.merge(overrides).to_h
          hash["variables"] = hash.fetch("variables", {}).merge("sql_log_bin" => 0) if @binlog
          hash
        end

        def with_server(&block)
          server = database.postgresql? ? { "database" => "postgres" } : {}
          hash = connection_config(server)
          hash.delete("database") if database.mysql?
          ScratchRecord.establish_connection(hash)
          ScratchRecord.connection_pool.with_connection(&block)
        ensure
          ScratchRecord.remove_connection
        end

        def row_counts
          ScratchRecord.establish_connection(connection_config)
          ScratchRecord.connection_pool.with_connection do |connection|
            connection.tables.sort.to_h do |table|
              [table, connection.select_value("SELECT COUNT(*) FROM #{connection.quote_table_name(table)}").to_i]
            end
          end
        end

        # Not DatabaseTasks.drop: it would point ActiveRecord::Base at the scratch database.
        def drop
          ScratchRecord.remove_connection
          return if database.sqlite?
          with_server { |connection| connection.drop_database(name) }
        end
      end
    end
  end
end
