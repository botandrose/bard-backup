require "bard/backup/s3_tree"
require "bard/backup/deleter"
require "bard/backup/local_backhoe"
require "bard/backup/cached_local_backhoe"
require "bard/backup/rails_credentials"

module Bard
  class Backup
    class S3Destination < Destination
      def call
        strategy.call(s3_tree, now)
        Deleter.new(s3_tree, now).call
        Bard::Backup.new(timestamp: now, destinations: [info])
      end

      def s3_tree
        @s3_tree ||= S3Tree.new(**resolved_config.slice(:endpoint, :path, :access_key_id, :secret_access_key, :session_token, :region, :encryption_key).compact)
      end

      def info
        resolved_config.slice(:name, :type, :path, :region)
      end

      private

      # The raw config enriched with Rails credentials (by name), defaults, the
      # computed endpoint, and the resolved encryption key.
      def resolved_config
        @resolved_config ||= begin
          credentials = RailsCredentials.find(name: config[:name])
          resolved = { type: :s3, region: "us-west-2" }.merge(credentials).merge(config)
          resolved[:endpoint] ||= "https://s3.#{resolved[:region]}.amazonaws.com"
          resolved[:encryption_key] ||= configured_encryption_key
          resolved
        end
      end

      def strategy
        return @strategy if @strategy
        @strategy = resolved_config.fetch(:strategy, LocalBackhoe)
        @strategy = Bard::Backup.const_get(@strategy) if @strategy.is_a?(String)
        @strategy
      end
    end
  end
end
