require "bard"
require "bard/plugins/backup"
require "bard/backup/database"
require "bard/backup/file_tree"
require "bard/backup/finder"
require "bard/backup/restore"
require "bard/backup/rekey"
require "bard/backup/railtie" if defined?(Rails)

module Bard
  class Backup
    FILE_TREE_KEYS = [:access_key_id, :secret_access_key, :session_token, :region, :encryption_key].freeze

    def self.create!(destination_hashes = nil, **config)
      backup = Database.create!(destination_hashes, **config)
      FileTree.create!(**config.slice(*FILE_TREE_KEYS))
      backup
    end

    def self.encrypt_existing!(destination_hashes = nil, **config)
      destination_hashes = [config] if destination_hashes.nil? && !config.empty?
      trees = Destination.resolve(destination_hashes)
        .select { |destination| destination.respond_to?(:s3_tree_config) }
        .map { |destination| [destination.s3_tree_config, destination.encryption_key, destination.info[:name]] }

      file_tree_config = FileTree.s3_tree_config(**config.slice(*FILE_TREE_KEYS, :data_paths, :project_name, :bucket))
      if file_tree_config
        key = file_tree_config.delete(:encryption_key)
        trees << [file_tree_config, key, file_tree_config[:path]]
      end

      missing = trees.reject { |_, key, _| key }.map(&:last)
      raise Error, "No encryption_key for #{missing.join(", ")}" if missing.any?

      trees.map { |tree_config, key, _| Rekey.call(tree_config:, to_key: key) }
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
