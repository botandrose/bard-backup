require "backhoe"
require "fileutils"
require "bard/backup/finder"

module Bard
  class Backup
    # Downloads a database backup from S3 and loads it into the local database.
    # The backup nearest +at+ is selected, decrypted if necessary, and loaded
    # via backhoe.
    class Restore
      def self.call(...)
        new(...).call
      end

      def initialize(at:, drop_and_create: true, destinations: nil)
        @at = at
        @drop_and_create = drop_and_create
        @destinations = destinations
      end

      def call
        backup = Finder.new(@destinations).find(at: @at)
        body = backup[:destination].s3_tree.get(backup[:filename])
        path = "/tmp/bard-backup-restore-#{File.basename(backup[:filename])}"
        File.binwrite(path, body)
        Backhoe.load(path, drop_and_create: @drop_and_create)

        Bard::Backup.new(
          timestamp: backup[:timestamp],
          size: body.bytesize,
          destinations: [backup[:destination].info],
        )
      ensure
        FileUtils.rm_f(path) if path
      end
    end
  end
end
