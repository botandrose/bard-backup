require "bard/config"

module Bard
  class Backup
    class Destination < Struct.new(:config)
      def self.build(config)
        klass = Bard::Backup.const_get("#{config[:type].to_s.capitalize}Destination")
        klass.new(config)
      end

      # Normalizes destination config into built destinations: falls back to the
      # configured destinations when none are given, and accepts a lone Hash or
      # an Array. Each destination resolves its own encryption key (see
      # #encryption_key), so callers don't have to inject it.
      def self.resolve(destination_hashes = nil)
        hashes = destination_hashes || Bard::Config.current.backup.destinations
        hashes = hashes.is_a?(Hash) ? [hashes] : Array(hashes)
        hashes.map { |hash| build(hash) }
      end

      def call
        raise NotImplementedError
      end

      private

      def encryption_key
        config[:encryption_key] || configured_encryption_key
      end

      def configured_encryption_key
        Bard::Config.current.backup.encryption_key
      end

      def now
        @now ||= config.fetch(:now, Time.now.utc)
      end
    end
  end
end

require "bard/backup/destination/s3_destination"
require "bard/backup/destination/upload_destination"
