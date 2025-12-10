Given("the S3 bucket {string} contains the backups from {string}") do |path, fixture_path|
  @s3_dir = Bard::Backup::S3Dir.new(path: path, **credentials)
  @s3_dir.empty!
  fixture_lines(fixture_path).each do |file_path|
    @s3_dir.put file_path, body: "TEST"
  end
end

When("I run the backup at {string}") do |timestamp|
  stub_const("Backhoe", FakeBackhoe.new)
  Bard::Backup.call(path: @s3_dir.path, now: Time.parse(timestamp), **credentials)
end

Then("the bucket should contain the backups from {string}") do |fixture_path|
  expect(@s3_dir.files).to eq(fixture_lines(fixture_path))
end

def fixture_lines(path)
  File.read(path).split("\n").map(&:strip)
end

def credentials
  @credentials ||= JSON.load_file("spec/support/credentials.json").transform_keys(&:to_sym)
end
