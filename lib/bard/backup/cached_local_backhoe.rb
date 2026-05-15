require "backhoe"

module Bard
  class Backup
    class CachedLocalBackhoe < Struct.new(:s3_tree, :now)
      def self.call *args
        new(*args).call
      end

      def call
        s3_tree.put_file(path, File.basename(path))
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
