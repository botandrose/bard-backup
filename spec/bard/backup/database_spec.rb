require "spec_helper"

RSpec.describe Bard::Backup::Database do
  before do
    stub_const("Backhoe", FakeBackhoe.new)

    allow_any_instance_of(Bard::Backup::UploadDestination).to receive(:upload_to_url)
  end

  describe ".create!" do
    context "when called with a hash as positional argument (bard-api style)" do
      it "creates a backup without Symbol to Integer conversion error" do
        backup = described_class.create!({
          name: "bard",
          type: :upload,
          urls: ["https://example.com/presigned-url"]
        })

        expect(backup).to be_a(Bard::Backup)
        expect(backup.destinations).to eq([])
        expect(backup.timestamp).to be_a(Time)
      end
    end

    context "when called with keyword arguments" do
      it "creates a backup" do
        backup = described_class.create!(
          name: "bard",
          type: :upload,
          urls: ["https://example.com/presigned-url"]
        )

        expect(backup).to be_a(Bard::Backup)
        expect(backup.destinations).to eq([])
        expect(backup.timestamp).to be_a(Time)
      end
    end

    context "when called with an array of hashes" do
      it "creates a backup from multiple destinations" do
        allow_any_instance_of(Bard::Backup::UploadDestination).to receive(:call).and_return(
          Bard::Backup.new(timestamp: Time.now.utc, size: 100, destinations: [])
        )

        backup = described_class.create!([
          {
            name: "primary",
            type: :upload,
            urls: ["https://example.com/presigned-url-1"]
          },
          {
            name: "secondary",
            type: :upload,
            urls: ["https://example.com/presigned-url-2"]
          }
        ])

        expect(backup).to be_a(Bard::Backup)
        expect(backup.destinations).to eq([])
        expect(backup.timestamp).to be_a(Time)
      end
    end

    context "with multiple destinations" do
      it "aggregates every destination's info into one backup" do
        now = Time.parse("2024-07-25T12:00:00Z")
        primary = double(call: Bard::Backup.new(timestamp: now, size: 10, destinations: [{ name: "primary" }]))
        secondary = double(call: Bard::Backup.new(timestamp: now, destinations: [{ name: "secondary" }]))
        allow(Bard::Backup::Destination).to receive(:resolve).and_return([primary, secondary])

        backup = described_class.create!([{ name: "primary" }, { name: "secondary" }])

        expect(backup.destinations).to eq([{ name: "primary" }, { name: "secondary" }])
        expect(backup.timestamp).to eq(now)
        expect(backup.size).to eq(10)
      end

      it "resolves all destinations with a single run timestamp" do
        allow(Bard::Backup::Destination).to receive(:resolve).and_return([])

        described_class.create!([{ type: :upload, urls: ["https://example.com"] }])

        expect(Bard::Backup::Destination).to have_received(:resolve).with(
          [{ type: :upload, urls: ["https://example.com"] }],
          now: an_instance_of(Time),
        )
      end
    end
  end
end
