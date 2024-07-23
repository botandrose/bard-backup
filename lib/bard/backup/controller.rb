require "backhoe"
require "bard/backup/s3_dir"

module Bard
  module Backup
    class Controller < Struct.new(:s3_path, :filename, :access_key, :secret_key)
      def call
        path = "/tmp/#{filename}"
        Backhoe.dump path
        s3_dir = S3Dir.new(path: s3_path, access_key:, secret_key:)
        s3_dir.put path
      end
    end
  end
end
