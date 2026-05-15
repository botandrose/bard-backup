require "bard/backup/s3_tree"
require "bard/backup/deleter"
require "bard/backup/local_backhoe"
require "bard/backup/cached_local_backhoe"

module Bard
  class Backup
    class S3Destination < Destination
      def call
        strategy.call(s3_tree, now)
        Deleter.new(s3_tree, now).call
      end

      def s3_tree
        @s3_tree ||= S3Tree.new(**config.slice(:endpoint, :path, :access_key_id, :secret_access_key, :region, :encryption_key))
      end

      def info
        config.slice(:name, :type, :path, :region)
      end

      private

      def config
        @config ||= begin
          config = { type: :s3, region: "us-west-2" }.merge(super)
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
