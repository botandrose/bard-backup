require "spec_helper"
require "rake"

RSpec.describe "bard:backup:encrypt" do
  before do
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    load "bard/backup/tasks.rake"
  end

  it "encrypts the configured destinations and data files with keys from Rails credentials" do
    allow(Bard::Config).to receive(:current).and_return(double(backup: double(destinations: [{ name: "primary", type: :s3 }])))
    allow(Bard::Backup::RailsCredentials).to receive(:find).with(name: "primary").and_return(path: "bucket/project", encryption_key: "k")
    allow(Bard::Backup::RailsCredentials).to receive(:find).with(no_args).and_return(path: "bucket/project", encryption_key: "k")

    expect(Bard::Backup).to receive(:encrypt_existing!)
      .with([{ path: "bucket/project", encryption_key: "k", name: "primary", type: :s3 }], path: "bucket/project", encryption_key: "k")
      .and_return([{ path: "bucket/project", encrypted: ["a.sql.gz", "b.sql.gz"], skipped: ["c.sql.gz"] }])

    expect { Rake::Task["bard:backup:encrypt"].invoke }
      .to output("bucket/project: encrypted 2, already encrypted 1\n").to_stdout
  end
end

RSpec.describe "bard:backup" do
  before do
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    load "bard/backup/tasks.rake"
    allow(Bard::Config).to receive(:current).and_return(double(backup: double(destinations: [{ name: "primary", type: :s3 }]), data: ["public/userfiles"]))
    allow(Bard::Backup::RailsCredentials).to receive(:find).and_return({})
  end

  it "backs up first, then fails when Active Storage keeps uploads on disk outside the declared data paths" do
    require "active_storage"
    require "active_storage/service"
    require "active_storage/service/disk_service"
    stub_const("ActiveStorage::Blob", double(service: ActiveStorage::Service::DiskService.new(root: File.expand_path("storage"))))
    expect(Bard::Backup).to receive(:create!).with([{ name: "primary", type: :s3 }])

    expect { Rake::Task["bard:backup"].invoke }.to raise_error(Bard::Backup::UncoveredUploads,
      'Active Storage keeps uploads on this server in storage, which bard.rb does not declare as data, so they are not backed up. Add it to `data` in bard.rb.')
  end
end
