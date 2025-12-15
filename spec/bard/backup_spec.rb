require "spec_helper"

RSpec.describe Bard::Backup do
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
  end
end
