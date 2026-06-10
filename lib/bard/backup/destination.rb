module Bard
  class Backup
    class Destination < Struct.new(:config)
      def self.build(config)
        klass = Bard::Backup.const_get("#{config[:type].to_s.capitalize}Destination")
        klass.new(config)
      end

      # Normalizes destination config into built destinations: falls back to the
      # configured destinations when none are given, accepts a lone Hash or an
      # Array, and injects the configured encryption key so encrypted payloads
      # are read and written transparently.
      def self.resolve(destination_hashes = nil)
        bard_config = defined?(Bard::Config) ? Bard::Config.current : nil
        hashes = destination_hashes || bard_config&.backup&.destinations || []
        hashes = hashes.is_a?(Hash) ? [hashes] : Array(hashes)

        if (encryption_key = bard_config&.backup&.encryption_key)
          hashes = hashes.map { |hash| { encryption_key: encryption_key, **hash } }
        end

        hashes.map { |hash| build(hash) }
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
