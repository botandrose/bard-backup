require "active_record"

module Bard
  class Backup
    class RestoreCheck
      class ScratchRecord < ActiveRecord::Base
        self.abstract_class = true
      end
    end
  end
end
