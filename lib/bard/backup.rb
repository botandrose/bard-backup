require "bard/backup/controller"

module Bard
  module Backup
    def self.call s3_path, access_key:, secret_key:, filename: "#{Time.now.utc.iso8601}.sql.gz"
      Controller.new(s3_path, filename, access_key, secret_key).call
    end
  end
end

