module Bard
  class Backup
    class Destination < Struct.new(:config)
      def self.build(config)
        klass = Bard::Backup.const_get("#{config[:type].to_s.capitalize}Destination")
        klass.new(config)
      end

      def call
        raise NotImplementedError
      end

      private

      def now
        @now ||= config.fetch(:now, Time.now.utc)
      end
    end
  end
end

require "bard/backup/destination/s3_destination"
require "bard/backup/destination/upload_destination"
