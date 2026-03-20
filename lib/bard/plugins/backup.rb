require "bard/config"

module Bard
  class BackupConfig
    attr_reader :destinations

    def initialize(&block)
      @destinations = []
      instance_eval(&block) if block_given?
    end

    def bard
      @bard = true
    end

    def bard?
      !!@bard
    end

    def disabled
      @disabled = true
    end

    def disabled?
      !!@disabled
    end

    def enabled?
      !disabled?
    end

    def s3(name, **kwargs)
      @destinations << {
        name: name,
        type: :s3,
        **kwargs,
      }
    end

    def self_managed?
      @destinations.any?
    end
  end
end

class Bard::Config
  def backup(value = nil, &block)
    if block
      @backup = Bard::BackupConfig.new(&block)
    elsif value == false
      @backup = Bard::BackupConfig.new { disabled }
    elsif value.nil?
      @backup ||= Bard::BackupConfig.new { bard }
    else
      raise ArgumentError, "backup accepts false or a block"
    end
  end

  def backup_enabled?
    backup == true
  end
end
