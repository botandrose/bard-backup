require "bard/backup/destination"
require "bard/backup/latest_finder"
require "bard/backup/railtie" if defined?(Rails)

module Bard
  class Backup
    def self.create!(destination_hashes = nil, **config)
      if destination_hashes.nil? && !config.empty?
        destination_hashes = [config]
      end
      destination_hashes ||= Bard::Config.current.backup.destinations
      Array(destination_hashes).each do |hash|
        Destination.build(hash).call
      end
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
