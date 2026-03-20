require "bard/backup/encryptor"

Given("the S3 bucket {string} contains the backups from {string}") do |path, fixture_path|
  @s3_dir = Bard::Backup::S3Dir.new(path: path, **credentials)
  @s3_dir.empty!
  fixture_lines(fixture_path).each do |file_path|
    @s3_dir.put file_path, body: "TEST"
  end
end

Given("the S3 bucket {string} is empty for backups") do |path|
  @s3_dir = Bard::Backup::S3Dir.new(path: path, **credentials)
  @s3_dir.empty!
end

When("I run the backup at {string}") do |timestamp|
  @fake_backhoe = FakeBackhoe.new
  stub_const("Backhoe", @fake_backhoe)
  Bard::Backup.create!(type: :s3, path: @s3_dir.path, now: Time.parse(timestamp), **credentials)
end

When("I run the backup at {string} with encryption key {string}") do |timestamp, key|
  @fake_backhoe = FakeBackhoe.new
  stub_const("Backhoe", @fake_backhoe)
  @encryption_key = key
  Bard::Backup.create!(type: :s3, path: @s3_dir.path, now: Time.parse(timestamp), encryption_key: key, **credentials)
end

Then("the bucket should contain the backups from {string}") do |fixture_path|
  expect(@s3_dir.files).to eq(fixture_lines(fixture_path))
end

Then("the raw S3 content of the latest backup should not equal the unencrypted dump") do
  file_name = @s3_dir.files.last
  raw_s3_dir = Bard::Backup::S3Dir.new(path: @s3_dir.path, **credentials)
  response = raw_s3_dir.send(:client).get_object(bucket: raw_s3_dir.bucket_name, key: [raw_s3_dir.folder_prefix, file_name].compact.join("/"))
  @raw_content = response.body.read
  expect(@raw_content).not_to eq("DATA")
end

Then("decrypting the latest backup with key {string} should return the unencrypted dump") do |key|
  encryptor = Bard::Backup::Encryptor.new(key)
  decrypted = encryptor.decrypt(@raw_content)
  expect(decrypted).to eq("DATA")
end

def fixture_lines(path)
  File.read(path).split("\n").map(&:strip)
end

def credentials
  @credentials ||= JSON.load_file("spec/support/credentials.json").transform_keys(&:to_sym)
end
