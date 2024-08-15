require "backhoe"

module Bard
  module Backup
    class LocalBackhoe
      def self.call s3_dir, now
        filename = "#{now.iso8601}.sql.gz"
        path = "/tmp/#{filename}"
        Backhoe.dump path
        s3_dir.mv path
      end
    end
  end
end
