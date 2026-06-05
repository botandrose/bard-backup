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
        @destination_hashes = self.class.resolve_destinations(destinations)
      end

      # Returns every backup as { timestamp:, destination:, filename: }.
      def all
        @destination_hashes.flat_map do |hash|
          destination = Destination.build(hash)
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

      # Resolves destination config the same way Database.create! does, so
      # encrypted backups decrypt transparently on read.
      def self.resolve_destinations(destinations)
        bard_config = defined?(Bard::Config) ? Bard::Config.current : nil
        hashes = destinations || bard_config&.backup&.destinations || []
        hashes = hashes.is_a?(Hash) ? [hashes] : Array(hashes)

        encryption_key = bard_config&.backup&.encryption_key
        if encryption_key
          hashes = hashes.map { |hash| { encryption_key: encryption_key, **hash } }
        end
        hashes
      end

      private

      def parse_timestamp(filename)
        filename =~ /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)/ ? Time.parse($1) : nil
      end
    end
  end
end
