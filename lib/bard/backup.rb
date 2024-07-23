require "bard/backup/controller"
require "bard/backup/s3_dir"
require "backhoe"

module Bard
  module Backup
    def self.call s3_path, access_key:, secret_key:, filename: "#{Time.now.utc.iso8601}.sql.gz"
      dumper = Backhoe
      s3_dir = S3Dir.new(path: s3_path, access_key:, secret_key:)
      Controller.new(dumper, s3_dir, filename).call
    end
  end
end

