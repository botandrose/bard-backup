require "bard/backup/destination"

module Bard
  class Backup
    module Database
      def self.create!(destination_hashes = nil, **config)
        if destination_hashes.nil? && !config.empty?
          destination_hashes = [config]
        end

        bard_config = defined?(Bard::Config) ? Bard::Config.current : nil
        destination_hashes ||= bard_config&.backup&.destinations || []

        destinations = if destination_hashes.is_a?(Hash)
          [destination_hashes]
        else
          Array(destination_hashes)
        end

        encryption_key = bard_config&.backup&.encryption_key
        if encryption_key
          destinations = destinations.map { |h| { encryption_key: encryption_key, **h } }
        end

        result = nil
        destinations.each do |hash|
          result = Backup::Destination.build(hash).call
        end
        result
      end
    end
  end
end
