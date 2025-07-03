require "backhoe"

module Bard
  class Backup
    class CachedLocalBackhoe < Struct.new(:s3_dir, :now)
      def self.call *args
        new(*args).call
      end

      def call
        s3_dir.put path
      end

      private

      def path
        @@path ||= begin
          filename = "#{now.iso8601}.sql.gz"
          path = "/tmp/#{filename}"
          Backhoe.dump path
          at_exit { FileUtils.rm_f path }
          path
        end
      end
    end
  end
end
