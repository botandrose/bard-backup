require "spec_helper"

RSpec.describe Bard::Backup::Destination do
  describe ".build" do
    it "returns an S3 destination when type is s3" do
      destination = described_class.build(type: :s3, name: "aws", path: "bucket/path")

      expect(destination).to be_a(Bard::Backup::S3Destination)
    end

    it "returns an upload destination when type is upload" do
      destination = described_class.build(type: :upload, urls: ["https://example.com"])

      expect(destination).to be_a(Bard::Backup::UploadDestination)
    end

    it "raises on unknown destination type" do
      expect { described_class.build(type: :ftp) }.to raise_error(NameError)
    end
  end
end
