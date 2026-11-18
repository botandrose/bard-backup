require "spec_helper"

RSpec.describe "Backing up into a bucket with Object Lock" do
  let(:client) { Aws::S3::Client.new(stub_responses: true, region: "us-west-2", access_key_id: "k", secret_access_key: "s") }

  before do
    hide_const("Rails")
    stub_const("Backhoe", FakeBackhoe.new)
    allow(Aws::S3::Client).to receive(:new).and_return(client)
    client.stub_responses(:list_objects_v2, contents: [])
  end

  def back_up(at)
    Bard::Backup::Database.create!(type: :s3, name: "bard-backup", path: "bard-backup/app", region: "us-west-2",
      access_key_id: "k", secret_access_key: "s", now: Time.parse(at))
  end

  def uploads
    client.api_requests.select { |request| request[:operation_name] == :put_object }.map { |request| request[:params] }
  end

  context "when the bucket has Object Lock enabled" do
    before do
      client.stub_responses(:get_object_lock_configuration, object_lock_configuration: {
        object_lock_enabled: "Enabled", rule: { default_retention: { mode: "GOVERNANCE", days: 14 } },
      })
    end

    it "locks an hourly dump under governance until the hourly window ends" do
      back_up("2026-11-18T13:00:04Z")

      expect(uploads.size).to eq(1)
      expect(uploads.first).to include(
        key: "app/2026-11-18T13:00:04Z.sql.gz",
        object_lock_mode: "GOVERNANCE",
        object_lock_retain_until_date: Time.parse("2026-11-20T13:00:00Z"),
        checksum_algorithm: "CRC32",
      )
    end

    it "locks the first dump of a month until the monthly window ends" do
      back_up("2026-12-01T00:00:04Z")

      expect(uploads.first).to include(object_lock_retain_until_date: Time.parse("2028-12-01T00:00:00Z"))
    end
  end

  context "when the bucket has no Object Lock configuration" do
    before do
      client.stub_responses(:get_object_lock_configuration, "ObjectLockConfigurationNotFoundError")
    end

    it "uploads the dump without a lock" do
      back_up("2026-11-18T13:00:04Z")

      expect(uploads.size).to eq(1)
      expect(uploads.first.keys).not_to include(:object_lock_mode, :object_lock_retain_until_date)
    end
  end

  context "when the app's AWS user may not read the lock configuration" do
    before do
      client.stub_responses(:get_object_lock_configuration, "AccessDenied")
    end

    it "fails before uploading rather than uploading an unlocked dump" do
      expect { back_up("2026-11-18T13:00:04Z") }.to raise_error(Aws::S3::Errors::AccessDenied)
      expect(uploads).to be_empty
    end
  end
end
