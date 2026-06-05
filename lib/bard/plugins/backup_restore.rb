# Registers the `bard backup restore` CLI subcommand. The actual work runs in
# the `bard:backup:restore` rake task, which boots Rails so it has the AWS
# credentials and database config it needs (mirroring how `bard data` shells out
# to `bin/rake db:load`).
require "bard/command"

class Bard::CLI
  class BackupCommands < Thor
    desc "restore [TIMESTAMP]", "restore the database backup nearest TIMESTAMP into the local database"
    long_desc <<~DESC
      Restores the database backup nearest TIMESTAMP (ISO-8601 UTC, e.g.
      2026-06-05T16:00:00Z) into the LOCAL database, dropping and recreating it.

      With no TIMESTAMP, lists the available backups instead of restoring.
    DESC
    def restore(timestamp = nil)
      if timestamp.nil?
        Bard::Command.run! "bin/rake bard:backup:restore", verbose: true
      else
        say "This will DROP and reload your LOCAL database from the backup nearest #{timestamp}.", :yellow
        unless yes?("Continue? (y/N)")
          say "Aborted."
          exit 1
        end
        Bard::Command.run! %(bin/rake "bard:backup:restore[#{timestamp}]"), verbose: true
      end
    rescue Bard::Command::Error => e
      say "!!! Running command failed: #{e.message}", :red
      exit 1
    end
  end

  desc "backup SUBCOMMAND", "database backup operations"
  subcommand "backup", BackupCommands
end
