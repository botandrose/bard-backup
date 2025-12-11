require "bard/config"

module Bard
  class Backup
    class NotFound < StandardError; end

    class LatestFinder
      def call
        destinations = Bard::Config.current.backup.destinations.map do |hash|
          Destination.build(hash)
        end

        all_backups = destinations.flat_map do |dest|
          dest.s3_dir.files.filter_map do |filename|
            timestamp = parse_timestamp(filename)
            next unless timestamp

            { timestamp: timestamp, destination: dest, filename: filename }
          end
        end

        raise NotFound, "No backups found" if all_backups.empty?

        latest = all_backups.max_by { |b| b[:timestamp] }

        Bard::Backup.new(
          timestamp: latest[:timestamp],
          size: get_file_size(latest[:destination].s3_dir, latest[:filename]),
          destinations: all_backups
            .select { |b| b[:timestamp] == latest[:timestamp] }
            .map { |b| b[:destination].info }
        )
      end

      private

      def parse_timestamp(filename)
        filename =~ /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)/ ? Time.parse($1) : nil
      end

      def get_file_size(s3_dir, filename)
        key = [s3_dir.folder_prefix, filename].compact.join("/")
        s3_dir.send(:client).head_object(bucket: s3_dir.bucket_name, key: key).content_length
      end
    end
  end
end
