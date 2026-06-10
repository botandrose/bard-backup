namespace :bard do
  desc "Backup the database and file trees to configured destinations"
  task :backup => :environment do
    require "bard/backup"
    require "bard/backup/rails_credentials"

    destinations = Bard::Config.current.backup.destinations.map do |dest|
      Bard::Backup::RailsCredentials.find(name: dest[:name]).merge(dest)
    end

    Bard::Backup.create!(destinations, **Bard::Backup::RailsCredentials.find)
  end

  namespace :backup do
    desc "Backup file trees to S3"
    task :data => :environment do
      require "bard/backup"
      require "bard/backup/rails_credentials"
      Bard::Backup::FileTree.create!(**Bard::Backup::RailsCredentials.find)
    end

    desc "Restore the database backup nearest a timestamp (no timestamp lists available backups)"
    task :restore, [:at] => :environment do |_task, args|
      require "bard/backup"
      require "bard/backup/rails_credentials"

      destinations = Bard::Config.current.backup.destinations
      if args[:at].to_s.strip.empty?
        timestamps = Bard::Backup.available(destinations: destinations)
        puts "Available backups:"
        timestamps.each { |timestamp| puts "  #{timestamp.iso8601}" }
      else
        backup = Bard::Backup.restore!(at: args[:at], destinations: destinations)
        puts "Restored database from backup #{backup.timestamp.iso8601}."
      end
    end
  end
end
