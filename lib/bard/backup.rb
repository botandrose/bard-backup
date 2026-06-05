require "bard"
require "bard/plugins/backup"
require "bard/plugins/encrypt"
require "bard/backup/database"
require "bard/backup/file_tree"
require "bard/backup/latest_finder"
require "bard/backup/finder"
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

    # Sorted list of available backup timestamps across the destinations.
    def self.available(destinations: nil)
      Finder.new(destinations).timestamps
    end

    # Downloads the backup nearest to +at+ (or the latest when +at+ is nil),
    # decrypts it if necessary, and loads it into the local database via backhoe.
    def self.restore!(at: nil, drop_and_create: true, destinations: nil)
      require "backhoe"
      require "fileutils"

      backup = Finder.new(destinations).find(at: at)
      body = backup[:destination].s3_tree.get(backup[:filename])
      path = "/tmp/bard-backup-restore-#{File.basename(backup[:filename])}"
      File.binwrite(path, body)
      Backhoe.load(path, drop_and_create: drop_and_create)

      new(timestamp: backup[:timestamp], size: body.bytesize, destinations: [backup[:destination].info])
    ensure
      FileUtils.rm_f(path) if path
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
