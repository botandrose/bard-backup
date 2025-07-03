require "bard/backup/s3_dir"
require "bard/backup/local_backhoe"
require "bard/backup/cached_local_backhoe"
require "bard/backup/deleter"

module Bard
  class Backup
    def self.call configs
      configs = [configs] if configs.is_a?(Hash)
      configs.each do |config|
        new(config).call
      end
    end

    def initialize config
      @config = config
    end
    attr_reader :config

    def call
      strategy.call(s3_dir, now)
      Deleter.new(s3_dir, now).call
    end

    def s3_dir
      @s3_dir ||= S3Dir.new(endpoint:, path:, access_key:, secret_key:, region:)
    end

    def strategy
      return @strategy if @strategy
      @strategy = config.fetch(:strategy, LocalBackhoe)
      if @strategy.is_a?(String)
        @strategy = Bard::Backup.const_get(@strategy)
      end
      @strategy
    end

    def path
      config.fetch(:path)
    end

    def access_key
      config[:access_key_id] || config[:access_key]
    end

    def secret_key
      config[:secret_access_key] || config[:secret_key]
    end

    def region
      config.fetch(:region, "us-west-2")
    end

    def now
      @now ||= config.fetch(:now, Time.now.utc)
    end

    def endpoint
      config.fetch(:endpoint, "https://s3.#{region}.amazonaws.com")
    end
  end
end
