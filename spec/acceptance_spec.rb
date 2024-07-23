RSpec.describe Bard::Backup do
  let(:credentials) { JSON.load_file("spec/support/credentials.json").symbolize_keys }
  let(:s3_dir) { Bard::Backup::S3Dir.new(path: "bard-backup-test/test", **credentials) }

  before do
    s3_dir.empty!
    stub_const "Backhoe", FakeBackhoe.new
  end

  it "uploads a new backhoe dump to the bucket" do
    described_class.call s3_dir.path, **credentials, filename: "2020-04-20T12:30:00Z.sql.gz"
    expect(s3_dir.keys).to eq([
      "test/2020-04-20T12:30:00Z.sql.gz",
    ])
  end
end

