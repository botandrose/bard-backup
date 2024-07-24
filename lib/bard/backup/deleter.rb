require "active_support"
require "active_support/core_ext/date_time/calculations"
require "active_support/core_ext/integer/time"

module Bard
  module Backup
    class Deleter < Struct.new(:s3_dir, :now)
      def call
        s3_dir.delete keys_to_delete
      end

      def keys_to_delete
        s3_dir.keys.select do |key|
          [
            CurrentFilter.new(now),
            HourlyFilter.new(now, 72),
            DailyFilter.new(now, 60),
            WeeklyFilter.new(now, 52),
            MonthlyFilter.new(now, 48),
            YearlyFilter.new(now),
          ].all? { |filter| !filter.cover?(key) }
        end
      end

      class BaseFilter < Struct.new(:now, :limit)
        def cover? key
          remote = DateTime.parse(key).beginning_of_hour
          (limit || 1).times.any? do |count|
            remote == for_count(count)
          end
        end
      end

      class CurrentFilter < BaseFilter
        def for_count count
          now.beginning_of_hour
        end
      end

      class HourlyFilter < BaseFilter
        def for_count count
          now.beginning_of_hour - count.hours
        end
      end

      class DailyFilter < BaseFilter
        def for_count count
          now.beginning_of_day - count.days
        end
      end

      class WeeklyFilter < BaseFilter
        def for_count count
          now.beginning_of_week - count.weeks
        end
      end

      class MonthlyFilter < BaseFilter
        def for_count count
          now.beginning_of_month - count.month
        end
      end

      class YearlyFilter < BaseFilter
        def for_count count
          now.beginning_of_year - count.years
        end
      end
    end
  end
end

