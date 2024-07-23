require "backhoe"
require "bard/backup/s3_dir"

module Bard
  class Backup < Struct.new(:s3_path, :filename, :access_key, :secret_key)
    def self.call s3_path, access_key:, secret_key:, filename: "#{Time.now.utc.iso8601}.sql.gz"
      new(s3_path, filename, access_key, secret_key).call
    end

    def call
      path = "/tmp/#{filename}"
      Backhoe.dump path
      s3_dir = S3Dir.new(path: s3_path, access_key:, secret_key:)
      s3_dir.put path
    end
  end
end
