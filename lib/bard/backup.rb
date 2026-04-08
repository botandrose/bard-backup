require "bard/backup/destination"
require "bard/backup/file_tree"
require "bard/backup/latest_finder"
require "bard/plugins/backup"
require "bard/backup/railtie" if defined?(Rails)

module Bard
  class Backup
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

      encryption_key = bard_config&.respond_to?(:encryption_key) ? bard_config.encryption_key : nil
      if encryption_key
        destinations = destinations.map { |h| { encryption_key: encryption_key, **h } }
      end

      result = nil
      destinations.each do |hash|
        result = Destination.build(hash).call
      end
      result
    end

    def self.latest
      LatestFinder.new.call
    end

    attr_reader :timestamp, :size, :destinations

    def initialize(timestamp:, size: nil, destinations: [])
      @timestamp = timestamp
      @size = size
      @destinations = destinations
    end

    def as_json(*)
      {
        timestamp: timestamp&.iso8601,
        size: size,
        destinations: destinations
      }.compact
    end
  end
end
