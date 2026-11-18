require "spec_helper"
require "sqlite3"
require "tmpdir"
require "zlib"

RSpec.describe Bard::Backup::RestoreCheck do
  let(:timestamp) { Time.parse("2024-07-25T12:00:00Z") }
  let(:filename) { "2024-07-25T12:00:00Z.sql.gz" }
  let(:s3_tree) { double("S3Tree") }
  let(:destination) { double("Destination", s3_tree: s3_tree, info: { name: "primary", type: :s3 }) }
  let(:finder) { instance_double(Bard::Backup::Finder, find: { timestamp:, destination:, filename: }) }

  around do |example|
    Dir.mktmpdir("restore-check-spec-") do |dir|
      @dir = dir
      example.run
    end
  end

  before do
    allow(Bard::Backup::Finder).to receive(:new).with([{ type: :s3 }]).and_return(finder)
  end

  def sqlite_bytes(tables)
    path = File.join(@dir, "source-#{tables.hash}.sqlite3")
    db = SQLite3::Database.new(path)
    db.execute "PRAGMA user_version = 1"
    tables.each do |table, rows|
      db.execute "CREATE TABLE #{table} (id INTEGER PRIMARY KEY)"
      rows.times { db.execute "INSERT INTO #{table} DEFAULT VALUES" }
    end
    db.close
    File.binread(path)
  end

  def check(body, adapter: "sqlite3")
    allow(s3_tree).to receive(:get).with(filename).and_return(body) if body
    database = adapter == "sqlite3" ? File.join(@dir, "live.sqlite3") : "app_production"
    described_class.call(destinations: [{ type: :s3 }], database: { "adapter" => adapter, "database" => database })
  end

  let(:healthy) { sqlite_bytes("schema_migrations" => 2, "users" => 3, "posts" => 0) }

  it "restores the latest backup and reports its tables and rows" do
    result = check(Zlib.gzip(healthy))

    expect(finder).to have_received(:find).with(no_args)
    expect(result.row_counts).to eq("schema_migrations" => 2, "users" => 3, "posts" => 0)
    expect(result.backup.timestamp).to eq(timestamp)
    expect(result.to_s).to eq("Restore check passed for backup 2024-07-25T12:00:00Z: 3 tables, 5 rows")
  end

  it "fails when the dump is not gzip, as when its head was zero-filled" do
    body = Zlib.gzip(healthy).b
    body[0, 512] = "\0" * 512

    expect { check(body) }.to raise_error(described_class::Failed,
      /\ARestore check failed for backup 2024-07-25T12:00:00Z \(primary\): the dump is not a valid gzip file/)
  end

  it "fails when the gzip CRC does not match" do
    body = Zlib.gzip(healthy).b
    body[-8] = (body[-8].ord ^ 0xff).chr

    expect { check(body) }.to raise_error(described_class::Failed, /the dump is not a valid gzip file: invalid compressed data -- crc error/)
  end

  it "fails when bytes trail the gzip stream, as when another dump was appended" do
    body = Zlib.gzip(healthy) + Zlib.gzip("-- another project's dump\n")

    expect { check(body) }.to raise_error(described_class::Failed, /the dump has \d+ unexpected bytes after its gzip stream/)
  end

  it "fails when the dump decompresses to nothing" do
    expect { check(Zlib.gzip("")) }.to raise_error(described_class::Failed, /the dump is empty/)
  end

  it "fails when a MySQL dump stops before mysqldump's completion line, without loading it" do
    body = Zlib.gzip("-- MySQL dump 10.13\nCREATE TABLE `users` (`id` int);\nINSERT INTO `users` VALUES (1);\n")
    expect(Backhoe::Load).not_to receive(:new)

    expect { check(body, adapter: "trilogy") }.to raise_error(described_class::Failed,
      /the MySQL dump has no "-- Dump completed" line, so it was cut short/)
  end

  it "fails when a PostgreSQL dump stops before pg_dump's completion line" do
    body = Zlib.gzip("--\n-- PostgreSQL database dump\n--\nCREATE TABLE users (id int);\n")

    expect { check(body, adapter: "postgresql") }.to raise_error(described_class::Failed,
      /the PostgreSQL dump has no "-- PostgreSQL database dump complete" line, so it was cut short/)
  end

  it "fails when an SQLite dump is not an SQLite database" do
    expect { check(Zlib.gzip("not a database")) }.to raise_error(described_class::Failed, /the dump is not an SQLite database/)
  end

  it "fails when the restored database has no tables" do
    expect { check(Zlib.gzip(sqlite_bytes({}))) }.to raise_error(described_class::Failed, /the restored database has no tables/)
  end

  it "fails when schema_migrations is missing and every table is empty" do
    body = Zlib.gzip(sqlite_bytes("users" => 0, "posts" => 0))

    expect { check(body) }.to raise_error(described_class::Failed,
      /schema_migrations is missing or empty; every table is empty/)
  end

  it "leaves no scratch database or downloaded dump behind, even when the check fails" do
    expect { check(Zlib.gzip(sqlite_bytes("users" => 0))) }.to raise_error(described_class::Failed)

    expect(Dir.glob(File.join(Dir.tmpdir, "bard-backup-restore-check-*"))).to be_empty
  end

  context "with a server database" do
    let(:connection) { double("connection", drop_database: nil) }
    let(:scratch_record) { Bard::Backup::RestoreCheck::ScratchRecord }
    let(:dump) { "-- MySQL dump\n-- Dump completed on 2024-07-25\n-- PostgreSQL database dump complete\n" }

    before do
      require "bard/backup/restore_check/scratch_record"
      allow(s3_tree).to receive(:get).with(filename).and_return(Zlib.gzip(dump))
      allow(scratch_record).to receive(:establish_connection)
      allow(scratch_record).to receive_message_chain(:connection_pool, :with_connection).and_yield(connection)
      expect(ActiveRecord::Base).not_to receive(:establish_connection)
    end

    it "loads a MySQL dump into a scratch database beside the live one, and drops it even when loading fails" do
      loaded_into = nil
      allow(Backhoe::Load).to receive(:new) { |database, *| loaded_into = database.name; raise "mysql exited 1" }

      expect { check(nil, adapter: "trilogy") }.to raise_error("mysql exited 1")

      expect(loaded_into).to eq("app_production_restore_check")
      expect(scratch_record).to have_received(:establish_connection).with({ "adapter" => "trilogy" })
      expect(connection).to have_received(:drop_database).with("app_production_restore_check")
    end

    it "drops a PostgreSQL scratch database from the maintenance database" do
      allow(Backhoe::Load).to receive(:new).and_return(double(call: nil))
      allow(connection).to receive(:tables).and_return(["schema_migrations", "users"])
      allow(connection).to receive(:quote_table_name) { |table| %("#{table}") }
      allow(connection).to receive(:select_value).and_return(1)

      expect(check(nil, adapter: "postgresql").row_counts).to eq("schema_migrations" => 1, "users" => 1)

      expect(scratch_record).to have_received(:establish_connection).with({ "adapter" => "postgresql", "database" => "postgres" })
      expect(connection).to have_received(:drop_database).with("app_production_restore_check")
    end
  end
end
