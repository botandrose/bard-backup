require "spec_helper"

RSpec.describe Bard::Backup do
  describe ".restore!" do
    let(:timestamp) { Time.parse("2024-07-25T12:00:00Z") }
    let(:s3_tree) { double("S3Tree", get: "DUMP-BODY") }
    let(:destination) { double("Destination", s3_tree: s3_tree, info: { name: "primary", type: :s3 }) }
    let(:backhoe) { spy("Backhoe") }
    let(:backup) { { timestamp: timestamp, destination: destination, filename: "2024-07-25T12:00:00Z.sql.gz" } }

    before do
      stub_const("Backhoe", backhoe)
      allow(Bard::Backup::Finder).to receive(:new).and_return(
        instance_double(Bard::Backup::Finder, find: backup)
      )
    end

    it "downloads the selected backup and loads it into the database" do
      result = described_class.restore!(at: "2024-07-25T12:10:00Z", destinations: [{ type: :s3, path: "b/p" }])

      expect(s3_tree).to have_received(:get).with("2024-07-25T12:00:00Z.sql.gz")
      expect(backhoe).to have_received(:load).with(
        "/tmp/bard-backup-restore-2024-07-25T12:00:00Z.sql.gz",
        drop_and_create: true,
      )
      expect(result.timestamp).to eq(timestamp)
      expect(result.size).to eq("DUMP-BODY".bytesize)
    end

    it "writes the dump to disk before loading and removes it afterward" do
      loaded_path = nil
      allow(backhoe).to receive(:load) do |path, **|
        loaded_path = path
        expect(File.binread(path)).to eq("DUMP-BODY")
      end

      described_class.restore!(destinations: [{ type: :s3, path: "b/p" }])

      expect(loaded_path).to eq("/tmp/bard-backup-restore-2024-07-25T12:00:00Z.sql.gz")
      expect(File).not_to exist(loaded_path)
    end
  end

  describe ".available" do
    it "delegates to the finder's sorted timestamps" do
      finder = instance_double(Bard::Backup::Finder, timestamps: [Time.parse("2024-07-25T12:00:00Z")])
      allow(Bard::Backup::Finder).to receive(:new).with([{ type: :s3 }]).and_return(finder)

      expect(described_class.available(destinations: [{ type: :s3 }])).to eq([Time.parse("2024-07-25T12:00:00Z")])
    end
  end
end
