require "bard/backup/s3_dir"
require "bard/backup/deleter"
require "bard/backup/local_backhoe"
require "bard/backup/cached_local_backhoe"

module Bard
  class Backup
    class S3Destination < Destination
      def call
        strategy.call(s3_dir, now)
        Deleter.new(s3_dir, now).call
      end

      def s3_dir
        @s3_dir ||= S3Dir.new(**config.slice(:endpoint, :path, :access_key_id, :secret_access_key, :region))
      end

      def info
        config.slice(:name, :type, :path, :region)
      end

      private

      def config
        @config ||= begin
          config = {}

          if defined?(Rails)
            credentials = Rails.application.credentials.bard_backup || []
            credentials = [credentials] if credentials.is_a?(Hash)
            config = credentials.find { |c| c[:name] == super[:name] } || {}
          end

          config = { type: :s3, region: "us-west-2" }.merge(config).merge(super)
          config[:endpoint] ||= "https://s3.#{config[:region]}.amazonaws.com"
          config
        end
      end

      def strategy
        return @strategy if @strategy
        @strategy = config.fetch(:strategy, LocalBackhoe)
        @strategy = Bard::Backup.const_get(@strategy) if @strategy.is_a?(String)
        @strategy
      end
    end
  end
end
