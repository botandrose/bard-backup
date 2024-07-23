require "bard/backup"
require "bard/backup/s3_dir"
require "json"
require "debug"

RSpec.describe "Bard::Backup" do
  let(:credentials) { JSON.load_file("spec/support/credentials.json").symbolize_keys }
  let(:s3_dir) { S3Dir.new(path: "bard-backup-test/test", **credentials) }

  before do
    s3_dir.empty!
    # s3_dir.put "tmp/2020-04-19T00:00:00Z.sql.gz", body: "DATA"
    stub_const "Backhoe", FakeBackhoe.new
  end

  it "uploads a new file to the bucket" do
    Bard::Backup.call s3_dir.path, **credentials, filename: "2020-04-20T12:30:00Z.sql.gz"
    expect(s3_dir.keys).to eq([
      "test/2020-04-20T12:30:00Z.sql.gz",
    ])
  end
end

class FakeBackhoe
  def dump path
    File.write(path, "DATA")
  end
end
