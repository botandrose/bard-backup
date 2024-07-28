require "bard/backup/controller"
require "bard/backup/deleter"
require "bard/backup/s3_dir"
require "backhoe"

module Bard
  module Backup
    def self.call s3_path, access_key:, secret_key:, region: "us-west-2", now: Time.now.utc
      dumper = Backhoe
      s3_dir = S3Dir.new(path: s3_path, access_key:, secret_key:, region:)
      Controller.new(dumper, s3_dir, now).call
      Deleter.new(s3_dir, now).call
    end
  end
end

