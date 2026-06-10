require "spec_helper"

RSpec.describe Bard::Backup do
  describe ".latest" do
    it "delegates to the finder" do
      sentinel = Bard::Backup.new(timestamp: Time.now.utc)
      finder = instance_double(Bard::Backup::Finder, latest: sentinel)
      allow(Bard::Backup::Finder).to receive(:new).and_return(finder)

      expect(described_class.latest).to be(sentinel)
    end
  end

  describe ".restore!" do
    it "delegates to Restore.call with the given options" do
      sentinel = Bard::Backup.new(timestamp: Time.now.utc)
      allow(Bard::Backup::Restore).to receive(:call).and_return(sentinel)

      result = described_class.restore!(at: "2024-07-25T12:00:00Z", destinations: [{ type: :s3 }])

      expect(Bard::Backup::Restore).to have_received(:call).with(
        at: "2024-07-25T12:00:00Z",
        drop_and_create: true,
        destinations: [{ type: :s3 }],
      )
      expect(result).to be(sentinel)
    end
  end

  describe ".available" do
    it "delegates to the finder's sorted timestamps" do
      finder = instance_double(Bard::Backup::Finder, timestamps: [Time.parse("2024-07-25T12:00:00Z")])
      allow(Bard::Backup::Finder).to receive(:new).with([{ type: :s3 }]).and_return(finder)

      expect(described_class.available(destinations: [{ type: :s3 }])).to eq([Time.parse("2024-07-25T12:00:00Z")])
    end
  end

  describe ".create!" do
    let(:backup_result) { Bard::Backup.new(timestamp: Time.now.utc, size: 42, destinations: []) }

    before do
      allow(Bard::Backup::Database).to receive(:create!).and_return(backup_result)
      allow(Bard::Backup::FileTree).to receive(:create!)
    end

    it "calls Database.create! and FileTree.create! with no args when none given" do
      result = described_class.create!

      expect(Bard::Backup::Database).to have_received(:create!).with(nil)
      expect(Bard::Backup::FileTree).to have_received(:create!).with(no_args)
      expect(result).to be(backup_result)
    end

    it "forwards all kwargs to Database and only AWS-cred kwargs to FileTree" do
      described_class.create!(
        type: :s3,
        path: "bard-backup/test-project",
        now: Time.parse("2024-07-25T12:00:03Z"),
        access_key_id: "AKIA",
        secret_access_key: "secret",
        session_token: "token",
        region: "us-west-2",
      )

      expect(Bard::Backup::Database).to have_received(:create!).with(
        nil,
        type: :s3,
        path: "bard-backup/test-project",
        now: Time.parse("2024-07-25T12:00:03Z"),
        access_key_id: "AKIA",
        secret_access_key: "secret",
        session_token: "token",
        region: "us-west-2",
      )
      expect(Bard::Backup::FileTree).to have_received(:create!).with(
        access_key_id: "AKIA",
        secret_access_key: "secret",
        session_token: "token",
        region: "us-west-2",
      )
    end

    it "forwards encryption_key to FileTree" do
      described_class.create!(type: :s3, path: "p", encryption_key: "key")

      expect(Bard::Backup::FileTree).to have_received(:create!).with(encryption_key: "key")
    end

    it "forwards an explicit destinations array plus kwargs separately" do
      destinations = [{ name: "primary", type: :upload, urls: ["https://example.com/u"] }]
      described_class.create!(
        destinations,
        access_key_id: "AKIA",
        secret_access_key: "secret",
        region: "us-west-2",
      )

      expect(Bard::Backup::Database).to have_received(:create!).with(
        destinations,
        access_key_id: "AKIA",
        secret_access_key: "secret",
        region: "us-west-2",
      )
      expect(Bard::Backup::FileTree).to have_received(:create!).with(
        access_key_id: "AKIA",
        secret_access_key: "secret",
        region: "us-west-2",
      )
    end
  end
end
