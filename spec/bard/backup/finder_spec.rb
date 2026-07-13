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

  describe "#available" do
    let(:s3_tree) do
      double("S3Tree",
        list_objects: filenames.to_h { |name| [name, "etag"] },
        folder_prefix: "project",
        bucket_name: "bucket",
      )
    end
    let(:destination) { double("Destination", s3_tree: s3_tree, info: { name: "primary", type: :s3, path: "bucket/project" }) }
    let(:client) { double("Client") }
    let(:sizes) do
      {
        "project/2024-07-25T11:00:00Z.sql.gz" => 100,
        "project/2024-07-25T12:00:00Z.sql.gz" => 200,
        "project/2024-07-25T13:00:00Z.sql.gz" => 300,
      }
    end

    before do
      allow(s3_tree).to receive(:client).and_return(client)
      allow(client).to receive(:head_object) do |bucket:, key:|
        double(content_length: sizes.fetch(key))
      end
    end

    it "returns a Bard::Backup per timestamp, sorted, each carrying its file size" do
      backups = finder.available

      expect(backups.map(&:timestamp)).to eq([
        Time.parse("2024-07-25T11:00:00Z"),
        Time.parse("2024-07-25T12:00:00Z"),
        Time.parse("2024-07-25T13:00:00Z"),
      ])
      expect(backups.map(&:size)).to eq([100, 200, 300])
      expect(backups).to all(be_a(Bard::Backup))
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

  describe "#latest" do
    let(:s3_tree) do
      double("S3Tree",
        list_objects: filenames.to_h { |name| [name, "etag"] },
        folder_prefix: "project",
        bucket_name: "bucket",
      )
    end
    let(:destination) { double("Destination", s3_tree: s3_tree, info: { name: "primary", type: :s3, path: "bucket/project" }) }
    let(:client) { double("Client") }

    before do
      allow(s3_tree).to receive(:client).and_return(client)
      allow(client).to receive(:head_object).and_return(double(content_length: 1234))
    end

    it "returns a Bard::Backup for the most recent backup with size and destination info" do
      backup = finder.latest

      expect(backup).to be_a(Bard::Backup)
      expect(backup.timestamp).to eq(Time.parse("2024-07-25T13:00:00Z"))
      expect(backup.size).to eq(1234)
      expect(backup.destinations).to eq([{ name: "primary", type: :s3, path: "bucket/project" }])
      expect(client).to have_received(:head_object).with(bucket: "bucket", key: "project/2024-07-25T13:00:00Z.sql.gz")
    end

    it "raises NotFound when there are no backups" do
      allow(s3_tree).to receive(:list_objects).and_return({})
      expect { finder.latest }.to raise_error(Bard::Backup::NotFound)
    end
  end

end
