require "bard/backup/destination"

module Bard
  class Backup
    module Database
      def self.create!(destination_hashes = nil, **config)
        if destination_hashes.nil? && !config.empty?
          destination_hashes = [config]
        end

        result = nil
        Destination.resolve(destination_hashes).each do |destination|
          result = destination.call
        end
        result
      end
    end
  end
end
