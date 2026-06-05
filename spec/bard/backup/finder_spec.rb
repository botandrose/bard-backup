require "spec_helper"

RSpec.describe Bard::Backup::Finder do
  let(:filenames) do
    [
      "2024-07-25T11:00:00Z.sql.gz",
      "2024-07-25T12:00:00Z.sql.gz",
      "2024-07-25T13:00:00Z.sql.gz",
      "not-a-backup.txt",
    ]
  end
  let(:s3_tree) { double("S3Tree", list_objects: filenames.to_h { |name| [name, "etag"] }) }
  let(:destination) { double("Destination", s3_tree: s3_tree) }

  subject(:finder) { described_class.new([{ type: :s3, path: "bucket/project" }]) }

  before do
    allow(Bard::Backup::Destination).to receive(:build).and_return(destination)
  end

  describe "#timestamps" do
    it "returns sorted, unique parsed timestamps, ignoring non-backup files" do
      expect(finder.timestamps).to eq([
        Time.parse("2024-07-25T11:00:00Z"),
        Time.parse("2024-07-25T12:00:00Z"),
        Time.parse("2024-07-25T13:00:00Z"),
      ])
    end
  end

  describe "#find" do
    it "returns the latest backup when no timestamp is given" do
      expect(finder.find[:filename]).to eq("2024-07-25T13:00:00Z.sql.gz")
    end

    it "returns the backup nearest the given timestamp" do
      expect(finder.find(at: "2024-07-25T12:10:00Z")[:filename]).to eq("2024-07-25T12:00:00Z.sql.gz")
      expect(finder.find(at: "2024-07-25T12:40:00Z")[:filename]).to eq("2024-07-25T13:00:00Z.sql.gz")
    end

    it "accepts a Time as the target" do
      expect(finder.find(at: Time.parse("2024-07-25T11:05:00Z"))[:filename]).to eq("2024-07-25T11:00:00Z.sql.gz")
    end

    it "raises NotFound when there are no backups" do
      allow(s3_tree).to receive(:list_objects).and_return({})
      expect { finder.find }.to raise_error(Bard::Backup::NotFound)
    end
  end

  describe ".resolve_destinations" do
    it "wraps a single hash in an array" do
      expect(described_class.resolve_destinations({ type: :s3 })).to eq([{ type: :s3 }])
    end
  end
end
