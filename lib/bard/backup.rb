require "bard/backup/database"
require "bard/backup/file_tree"
require "bard/backup/latest_finder"
require "bard"
require "bard/backup/railtie" if defined?(Rails)

module Bard
  class Backup
    FILE_TREE_KEYS = [:access_key_id, :secret_access_key, :session_token, :region, :encryption_key].freeze

    def self.create!(destination_hashes = nil, **config)
      backup = Database.create!(destination_hashes, **config)
      FileTree.create!(**config.slice(*FILE_TREE_KEYS))
      backup
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
