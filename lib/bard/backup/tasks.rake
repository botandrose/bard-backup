namespace :bard do
  desc "Backup the database to configured destinations"
  task :backup => :environment do
    require "bard/backup"
    Bard::Backup.create!
  end
end
