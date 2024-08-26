require "active_support"
require "active_support/core_ext/date_time/calculations"
require "active_support/core_ext/integer/time"

module Bard
  module Backup
    class Deleter < Struct.new(:s3_dir, :now)
      def call
        s3_dir.delete files_to_delete
      end

      def files_to_delete
        s3_dir.files.select do |file|
          [
            Filter.new(now, 72, :hours),
            Filter.new(now, 60, :days),
            Filter.new(now, 52, :weeks),
            Filter.new(now, 48, :months),
            Filter.new(now, 100, :years),
          ].all? { |filter| !filter.cover?(file) }
        end
      end

      class Filter < Struct.new(:now, :limit, :unit)
        def cover? file
          remote = DateTime.parse(file).beginning_of_hour
          limit.times.any? do |count|
            remote == ago(count)
          end
        end

        private

        def ago count
          now.send(:"beginning_of_#{unit.to_s.singularize}") - count.send(unit)
        end
      end
    end
  end
end

