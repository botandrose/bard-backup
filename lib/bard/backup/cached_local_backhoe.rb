require "backhoe"
require "bard/config"
require "fileutils"
require "tmpdir"

module Bard
  class Backup
    class CachedLocalBackhoe < Struct.new(:s3_tree, :now)
      class << self
        attr_accessor :dump_dir
      end

      def self.call *args
        new(*args).call
      end

      def call
        s3_tree.put_file(path, filename)
      end

      private

      def filename
        "#{now.iso8601}.sql.gz"
      end

      def path
        cached = self.class.dump_dir && File.join(self.class.dump_dir, filename)
        return cached if cached && File.exist?(cached)

        FileUtils.rm_rf(self.class.dump_dir) if self.class.dump_dir
        self.class.dump_dir = dir = Dir.mktmpdir("#{Bard::Config.current.project_name}-backup-")
        at_exit { FileUtils.rm_rf dir }
        File.join(dir, filename).tap { |path| Backhoe.dump path }
      end
    end
  end
end
