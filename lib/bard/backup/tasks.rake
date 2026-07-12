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

    desc "Re-encrypt all S3 backups from the prior master key (ENV BARD_ROTATE_OLD_KEY) to the current one"
    task :reencrypt => :environment do
      require "bard/backup"
      # Keys travel via ENV, never argv, so the master key never lands in shell/process history.
      old_key = ENV.fetch("BARD_ROTATE_OLD_KEY").strip
      new_key = (ENV["BARD_ROTATE_NEW_KEY"] || File.read("config/master.key")).strip
      keys = Bard::Backup.reencrypt!(old_key: old_key, new_key: new_key)
      puts "Re-encrypted #{keys.length} backup object(s) across all S3 destinations."
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
