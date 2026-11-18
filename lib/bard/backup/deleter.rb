require "active_support"
require "active_support/core_ext/date_time/calculations"
require "active_support/core_ext/integer/time"

module Bard
  class Backup
    class Deleter < Struct.new(:s3_tree, :now)
      WINDOWS = [[48, :hours], [30, :days], [26, :weeks], [24, :months], [25, :years]].freeze
      private_constant :WINDOWS

      # The moment the hourly run first deletes a dump taken at +timestamp+.
      def self.retain_until(timestamp)
        WINDOWS.filter_map { |limit, unit| Filter.new(nil, limit, unit).retain_until(timestamp) }.max
      end

      def call
        s3_tree.delete_keys files_to_delete
      end

      def files_to_delete
        filters = WINDOWS.map { |limit, unit| Filter.new(now, limit, unit) }
        s3_tree.list_objects.keys.select do |file|
          filters.all? { |filter| !filter.cover?(file) }
        end
      end

      class Filter < Struct.new(:now, :limit, :unit)
        def cover? file
          remote = DateTime.parse(file).beginning_of_hour
          limit.times.any? do |count|
            remote == ago(count)
          end
        end

        def retain_until(timestamp)
          hour = timestamp.utc.beginning_of_hour
          hour + limit.send(unit) if hour == hour.send(:"beginning_of_#{unit.to_s.singularize}")
        end

        private

        def ago count
          now.send(:"beginning_of_#{unit.to_s.singularize}") - count.send(unit)
        end
      end
    end
  end
end
