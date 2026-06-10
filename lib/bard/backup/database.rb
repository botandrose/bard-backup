require "bard/backup/destination"

module Bard
  class Backup
    module Database
      def self.create!(destination_hashes = nil, **config)
        if destination_hashes.nil? && !config.empty?
          destination_hashes = [config]
        end

        now = Time.now.utc
        backups = Destination.resolve(destination_hashes, now: now).map(&:call)
        return nil if backups.empty?

        Bard::Backup.new(
          timestamp: backups.first.timestamp,
          size: backups.first.size,
          destinations: backups.flat_map(&:destinations),
        )
      end
    end
  end
end
