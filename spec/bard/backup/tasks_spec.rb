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
