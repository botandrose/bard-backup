require "bard/plugins/backup"

module Bard
  class BackupConfig
    def encrypt(value = nil)
      if value.nil?
        @encrypt
      else
        @encrypt = value
      end
    end

    def encryption_key
      return nil unless encrypt
      File.read("config/master.key").strip
    end
  end
end
