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

  describe ".resolve" do
    it "builds a destination from a single hash" do
      destinations = described_class.resolve(type: :s3, name: "aws", path: "bucket/path")

      expect(destinations.map(&:class)).to eq([Bard::Backup::S3Destination])
    end

    it "builds a destination for each hash in an array" do
      destinations = described_class.resolve([
        { type: :s3, name: "a", path: "bucket/a" },
        { type: :upload, urls: ["https://example.com"] },
      ])

      expect(destinations.map(&:class)).to eq([Bard::Backup::S3Destination, Bard::Backup::UploadDestination])
    end

    it "falls back to the configured destinations when none are given" do
      backup_config = double(destinations: [{ type: :upload, urls: ["https://example.com"] }], encryption_key: nil)
      allow(Bard::Config).to receive(:current).and_return(double(backup: backup_config))

      destinations = described_class.resolve

      expect(destinations.map(&:class)).to eq([Bard::Backup::UploadDestination])
    end

    it "injects the configured encryption key into each hash before building" do
      backup_config = double(destinations: [{ type: :s3, name: "a", path: "bucket/a" }], encryption_key: "secret-key")
      allow(Bard::Config).to receive(:current).and_return(double(backup: backup_config))
      allow(described_class).to receive(:build).and_call_original

      described_class.resolve

      expect(described_class).to have_received(:build).with(hash_including(encryption_key: "secret-key"))
    end
  end
end
