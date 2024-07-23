require "json"
require "aws-sdk-s3"
require "rexml"
require "debug"

RSpec.describe "Bard::Backup" do
  let(:credentials) { JSON.load_file("spec/support/credentials.json").symbolize_keys }
  let(:s3_dir) { S3Dir.new(path: "bard-backup-test/test", **credentials) }

  before do
    s3_dir.empty!
    stub_const "Backhoe", FakeBackhoe.new
  end

  it "uploads a new file to the bucket" do
    Bard::Backup.call s3_dir.path, **credentials, filename: "2020-04-20T12:30:00Z.sql.gz"
    expect(s3_dir.keys).to eq([
      "test/2020-04-20T12:30:00Z.sql.gz",
    ])
  end
end

class S3Dir < Data.define(:path, :access_key, :secret_key)
  def keys
    response = client.list_objects_v2({
      bucket: bucket_name,
      prefix: folder_prefix,
    })
    raise if response.is_truncated
    response.contents.map(&:key)
  end

  def empty!
    keys.each_slice(1000) do |key_batch|
      objects_to_delete = key_batch.map { |key| { key: key } }
      client.delete_objects({
        bucket: bucket_name,
        delete: {
          objects: objects_to_delete,
          quiet: true,
        }
      })
    end
  end

  def bucket_name
    path.split("/").first
  end

  def folder_prefix
    path.split("/")[1..].join("/")
  end

  private

  def client
    Aws::S3::Client.new({
      region: "us-west-2",
      access_key_id: access_key,
      secret_access_key: secret_key,
    })
  end
end

class FakeBackhoe
  def dump path
    File.write(path, "DATA")
  end
end
