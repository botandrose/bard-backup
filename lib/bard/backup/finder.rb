require "time"
require "bard/config"
require "bard/backup/destination"

module Bard
  class Backup
    class NotFound < StandardError; end

    # Locates database backups across the configured destinations and selects
    # one by timestamp. Used by both restore (find a specific backup) and
    # listing (enumerate available timestamps).
    class Finder
      def initialize(destinations = nil)
        @destinations = Destination.resolve(destinations)
      end

      # Returns every backup as { timestamp:, destination:, filename: }.
      def all
        @destinations.flat_map do |destination|
          destination.s3_tree.list_objects.keys.filter_map do |filename|
            timestamp = parse_timestamp(filename)
            next unless timestamp
            { timestamp: timestamp, destination: destination, filename: filename }
          end
        end
      end

      # Sorted, unique list of available backup timestamps.
      def timestamps
        all.map { |backup| backup[:timestamp] }.uniq.sort
      end

      # Selects a single backup. With no target, returns the latest. With a
      # target time, returns the backup nearest to it (backups run hourly via
      # cron, so an exact timestamp match is not guaranteed).
      def find(at: nil)
        backups = all
        raise NotFound, "No backups found" if backups.empty?

        if at.nil?
          backups.max_by { |backup| backup[:timestamp] }
        else
          target = at.is_a?(Time) ? at : Time.parse(at.to_s)
          backups.min_by { |backup| (backup[:timestamp] - target).abs }
        end
      end

      # Returns a Bard::Backup describing the most recent backup, including its
      # size and the info of every destination that holds that timestamp.
      def latest
        backups = all
        raise NotFound, "No backups found" if backups.empty?

        newest = backups.max_by { |backup| backup[:timestamp] }
        Bard::Backup.new(
          timestamp: newest[:timestamp],
          size: file_size(newest[:destination].s3_tree, newest[:filename]),
          destinations: backups
            .select { |backup| backup[:timestamp] == newest[:timestamp] }
            .map { |backup| backup[:destination].info },
        )
      end

      private

      def file_size(s3_tree, filename)
        key = [s3_tree.folder_prefix, filename].compact.join("/")
        s3_tree.send(:client).head_object(bucket: s3_tree.bucket_name, key: key).content_length
      end

      def parse_timestamp(filename)
        filename =~ /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)/ ? Time.parse($1) : nil
      end
    end
  end
end
