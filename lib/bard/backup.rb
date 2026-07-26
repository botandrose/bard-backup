require "bard"
require "bard/plugins/backup"
require "bard/backup/database"
require "bard/backup/file_tree"
require "bard/backup/finder"
require "bard/backup/restore"
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
      Finder.new.latest
    end

    def self.available(destinations: nil)
      Finder.new(destinations).available
    end

    def self.restore!(at:, drop_and_create: true, destinations: nil)
      Restore.call(at: at, drop_and_create: drop_and_create, destinations: destinations)
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

    def human_size
      units = %w[Bytes KB MB GB TB PB EB]
      value, unit = size.to_f, 0
      while value >= 1024 && unit < units.size - 1
        value /= 1024
        unit += 1
      end
      format("%5.2f %s", value, units[unit])
    end
  end
end
