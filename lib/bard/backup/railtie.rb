require "bard/backup"
require "rails"

module Bard
  class Backup
    class Railtie < Rails::Railtie
      rake_tasks do
        load "bard/backup/tasks.rake"
      end
    end
  end
end
