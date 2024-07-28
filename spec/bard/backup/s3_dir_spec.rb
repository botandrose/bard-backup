require "bard/backup/deleter"

RSpec.describe Bard::Backup::S3Dir do
  let(:access_key) { "abc" }
  let(:secret_key) { "123" }
  let(:region) { "usa" }

  describe "#bucket_name" do
    it "is the first part of the path" do
      subject = described_class.new(path: "bard-backup/test", access_key:, secret_key:, region:)
      expect(subject.bucket_name).to eq "bard-backup"
    end

    it "is the whole path if no subdirectory" do
      subject = described_class.new(path: "bard-backup", access_key:, secret_key:, region:)
      expect(subject.bucket_name).to eq "bard-backup"
    end
  end

  describe "#folder_prefix" do
    it "is the last part of the path" do
      subject = described_class.new(path: "bard-backup/test", access_key:, secret_key:, region:)
      expect(subject.folder_prefix).to eq "test"
    end

    it "is nil if no subdirectory" do
      subject = described_class.new(path: "bard-backup", access_key:, secret_key:, region:)
      expect(subject.folder_prefix).to be_nil
    end
  end
end

