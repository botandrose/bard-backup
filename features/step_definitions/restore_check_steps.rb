require "sqlite3"
require "tmpdir"
require "zlib"

After do
  FileUtils.rm_rf(@restore_check_dir) if @restore_check_dir
end

def restore_check_dir = @restore_check_dir ||= Dir.mktmpdir("restore-check-steps-")

def live_database_path = File.join(restore_check_dir, "live.sqlite3")

def sqlite_dump(tables)
  path = File.join(restore_check_dir, "dump-source-#{tables.size}.sqlite3")
  db = SQLite3::Database.new(path)
  db.execute "PRAGMA user_version = 1"
  tables.each do |table, rows|
    db.execute "CREATE TABLE #{table} (id INTEGER PRIMARY KEY)"
    rows.times { db.execute "INSERT INTO #{table} DEFAULT VALUES" }
  end
  db.close
  Zlib.gzip(File.binread(path))
end

Given("the live database has a {string} table with {int} rows") do |table, rows|
  db = SQLite3::Database.new(live_database_path)
  db.execute "CREATE TABLE #{table} (id INTEGER PRIMARY KEY)"
  rows.times { db.execute "INSERT INTO #{table} DEFAULT VALUES" }
  db.close
end

Given("the S3 bucket {string} holds a backup at {string} of a database with no tables") do |path, timestamp|
  @s3_tree = Bard::Backup::S3Tree.new(path: namespaced(path), **credentials)
  @s3_tree.empty!
  @s3_tree.put_body "#{timestamp}.sql.gz", sqlite_dump({})
end

Given("it holds a backup at {string} of a database with these tables:") do |timestamp, table|
  tables = table.hashes.to_h { |row| [row["table"], Integer(row["rows"])] }
  @s3_tree.put_body "#{timestamp}.sql.gz", sqlite_dump(tables)
end

When("I check that the latest backup restores") do
  @restore_check = Bard::Backup.check_restore!(
    destinations: [{ type: :s3, path: @s3_tree.path, **credentials }],
    database: { "adapter" => "sqlite3", "database" => live_database_path },
  )
end

Then("the restore check should report {string}") do |report|
  expect(@restore_check.to_s).to eq(report)
end

Then("the scratch database should be gone") do
  expect(Dir.glob(File.join(Dir.tmpdir, "bard-backup-restore-check-*"))).to be_empty
end

Then("the live database should still have a {string} table with {int} rows") do |table, rows|
  db = SQLite3::Database.new(live_database_path)
  expect(db.get_first_value("SELECT COUNT(*) FROM #{table}")).to eq(rows)
  db.close
end
