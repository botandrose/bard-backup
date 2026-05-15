require "bard/backup/rails_credentials"

namespace :bard do
  desc "Backup the database and file trees to configured destinations"
  task :backup => :environment do
    require "bard/backup"

    destinations = Bard::Config.current.backup.destinations.map do |dest|
      Bard::Backup::RailsCredentials.find(name: dest[:name]).merge(dest)
    end

    Bard::Backup.create!(destinations, **Bard::Backup::RailsCredentials.find)
  end

  namespace :backup do
    desc "Backup file trees to S3"
    task :data => :environment do
      require "bard/backup"
      Bard::Backup::FileTree.create!(**Bard::Backup::RailsCredentials.find)
    end
  end
end
