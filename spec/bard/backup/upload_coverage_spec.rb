require "spec_helper"
require "active_storage"
require "active_storage/service"
require "active_storage/service/disk_service"
require "active_storage/service/mirror_service"
require "active_storage/service/s3_service"

RSpec.describe Bard::Backup::UploadCoverage do
  def disk(root) = ActiveStorage::Service::DiskService.new(root: File.expand_path(root))
  def s3 = ActiveStorage::Service::S3Service.new(bucket: "uploads", region: "us-west-2", access_key_id: "a", secret_access_key: "b")
  def mirror(primary, *mirrors) = ActiveStorage::Service::MirrorService.new(primary:, mirrors:)
  def check!(service, data_paths) = described_class.check!(service, data_paths)

  it "passes when the disk service root is a declared data path" do
    expect { check!(disk("storage"), ["public/userfiles", "./storage"]) }.not_to raise_error
  end

  it "passes when the disk service root is inside a declared data path" do
    expect { check!(disk("public/system/storage"), ["public/system"]) }.not_to raise_error
  end

  it "fails when no declared data path holds the disk service root" do
    expect { check!(disk("storage"), ["stor", "storage-old"]) }.to raise_error(Bard::Backup::UncoveredUploads, /uploads on this server in storage,/)
  end

  it "names an absolute root outside the app" do
    expect { check!(disk("/srv/uploads"), []) }.to raise_error(Bard::Backup::UncoveredUploads, %r{in /srv/uploads,})
  end

  it "passes when uploads live in a cloud service" do
    expect { check!(s3, []) }.not_to raise_error
  end

  it "passes when a mirror copies disk uploads to a cloud service" do
    expect { check!(mirror(disk("storage"), s3), []) }.not_to raise_error
  end

  it "fails when a mirror only copies between uncovered disks" do
    expect { check!(mirror(disk("storage"), disk("/mnt/uploads")), []) }
      .to raise_error(Bard::Backup::UncoveredUploads, %r{in storage and /mnt/uploads,})
  end

  it "passes when the app does not use Active Storage" do
    expect { check!(nil, []) }.not_to raise_error
  end
end
