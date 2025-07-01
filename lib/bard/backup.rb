require "bard/backup/s3_dir"
require "bard/backup/local_backhoe"
require "bard/backup/deleter"

module Bard
  module Backup
    def self.call s3_path, region: "us-west-2", now: Time.now.utc, strategy: LocalBackhoe, **kwargs
      endpoint = kwargs[:endpoint] || "https://s3.#{region}.amazonaws.com"
      access_key = kwargs[:access_key_id] || kwargs[:access_key]
      secret_key = kwargs[:secret_access_key] || kwargs[:secret_key]
      s3_dir = S3Dir.new(endpoint:, path: s3_path, access_key:, secret_key:, region:)
      strategy.call(s3_dir, now)
      Deleter.new(s3_dir, now).call
    end
  end
end

