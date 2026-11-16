require "backhoe"
require "bard/config"
require "tmpdir"

module Bard
  class Backup
    class LocalBackhoe
      def self.call s3_tree, now
        Dir.mktmpdir("#{Bard::Config.current.project_name}-backup-") do |dir|
          path = File.join(dir, "#{now.iso8601}.sql.gz")
          Backhoe.dump path
          s3_tree.mv path
        end
      end
    end
  end
end
