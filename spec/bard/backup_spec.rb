require "spec_helper"

RSpec.describe Bard::Backup do
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
