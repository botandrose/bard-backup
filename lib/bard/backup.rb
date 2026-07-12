require "bard"
require "bard/plugins/backup"
require "bard/plugins/encrypt"
require "bard/backup/database"
require "bard/backup/file_tree"
require "bard/backup/finder"
require "bard/backup/restore"
require "bard/backup/reencryptor"
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
      Finder.new(destinations).timestamps
    end

    def self.restore!(at:, drop_and_create: true, destinations: nil)
      Restore.call(at: at, drop_and_create: drop_and_create, destinations: destinations)
    end

    # Re-encrypts every S3 backup from old_key to new_key, in place. Called by `bard rotate`
    # after the master key changes. Returns the re-encrypted keys per destination.
    def self.reencrypt!(old_key:, new_key:, destinations: nil)
      reencryptor = Reencryptor.new(old_key: old_key, new_key: new_key)
      Destination.resolve(destinations)
        .select { |destination| destination.respond_to?(:s3_tree_config) }
        .flat_map { |destination| reencryptor.call(destination.s3_tree_config) }
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
