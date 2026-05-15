require "backhoe"

module Bard
  class Backup
    class LocalBackhoe
      def self.call s3_tree, now
        filename = "#{now.iso8601}.sql.gz"
        path = "/tmp/#{filename}"
        Backhoe.dump path
        s3_tree.mv path
      end
    end
  end
end
