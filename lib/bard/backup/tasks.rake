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

    desc "Encrypt the backups and data files stored before encryption was enabled"
    task :encrypt => :environment do
      require "bard/backup"
      require "bard/backup/rails_credentials"

      destinations = Bard::Config.current.backup.destinations.map do |dest|
        Bard::Backup::RailsCredentials.find(name: dest[:name]).merge(dest)
      end

      Bard::Backup.encrypt_existing!(destinations, **Bard::Backup::RailsCredentials.find).each do |result|
        gone = Array(result[:gone])
        puts "#{result[:path]}: encrypted #{result[:encrypted].size}, already encrypted #{result[:skipped].size}#{", gone before it could be read #{gone.size}" if gone.any?}"
      end
    end

    desc "Restore the database backup nearest a timestamp (no timestamp lists available backups)"
    task :restore, [:at] => :environment do |_task, args|
      require "bard/backup"
      require "bard/backup/rails_credentials"

      destinations = Bard::Config.current.backup.destinations
      if args[:at].to_s.strip.empty?
        backups = Bard::Backup.available(destinations: destinations)
        puts "Available backups:"
        backups.each do |backup|
          puts "  #{backup.timestamp.iso8601}  #{backup.human_size}"
        end
      else
        backup = Bard::Backup.restore!(at: args[:at], destinations: destinations)
        puts "Restored database from backup #{backup.timestamp.iso8601}."
      end
    end
  end
end
