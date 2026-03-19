namespace :bard do
  desc "Backup the database and file trees to configured destinations"
  task :backup => :environment do
    require "bard/backup"
    Bard::Backup.create!
    Bard::Backup::FileTree.create!
  end

  namespace :backup do
    desc "Backup file trees to S3"
    task :data => :environment do
      require "bard/backup"
      Bard::Backup::FileTree.create!
    end
  end
end
