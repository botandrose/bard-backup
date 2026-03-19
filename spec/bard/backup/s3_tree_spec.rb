require "bard/backup/s3_tree"

RSpec.describe Bard::Backup::S3Tree do
  let(:access_key_id) { "abc" }
  let(:secret_access_key) { "123" }
  let(:region) { "usa" }

  describe "#bucket_name" do
    it "is the first part of the path" do
      subject = described_class.new(path: "bard-data/my-project", access_key_id:, secret_access_key:, region:)
      expect(subject.bucket_name).to eq "bard-data"
    end

    it "is the whole path if no subdirectory" do
      subject = described_class.new(path: "bard-data", access_key_id:, secret_access_key:, region:)
      expect(subject.bucket_name).to eq "bard-data"
    end
  end

  describe "#folder_prefix" do
    it "is the rest of the path after bucket name" do
      subject = described_class.new(path: "bard-data/my-project", access_key_id:, secret_access_key:, region:)
      expect(subject.folder_prefix).to eq "my-project"
    end

    it "supports nested paths" do
      subject = described_class.new(path: "bard-data/my-project/sub", access_key_id:, secret_access_key:, region:)
      expect(subject.folder_prefix).to eq "my-project/sub"
    end

    it "is nil if no subdirectory" do
      subject = described_class.new(path: "bard-data", access_key_id:, secret_access_key:, region:)
      expect(subject.folder_prefix).to be_nil
    end
  end
end
