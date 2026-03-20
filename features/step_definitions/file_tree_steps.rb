require "bard/backup/file_tree"
require "aws-sdk-core"
require "fileutils"

Given("the S3 bucket {string} is empty") do |path|
  @s3_tree = Bard::Backup::S3Tree.new(path: path, **s3_credentials_for(path))
  @s3_tree.empty!
end

Given("the local data directory {string} contains:") do |dir, table|
  table.hashes.each do |row|
    path = File.join(dir, row["path"])
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, row["content"])
  end
end

When("I sync file trees for data paths {string}") do |paths_string|
  data_paths = paths_string.split(",")
  Bard::Backup::FileTree.create!(
    data_paths: data_paths,
    project_name: "test-file-tree",
    bucket: "bard-backup-test",
    **credentials,
  )
end

When("I sync file trees for data paths {string} using STS credentials scoped to {string}") do |paths_string, project_name|
  data_paths = paths_string.split(",")
  temp = assume_role_credentials(project_name)
  Bard::Backup::FileTree.create!(
    data_paths: data_paths,
    project_name: project_name,
    bucket: "bard-data",
    access_key_id: temp.access_key_id,
    secret_access_key: temp.secret_access_key,
    session_token: temp.session_token,
    region: credentials[:region],
  )
end

When("I update the local file {string} with content {string}") do |path, content|
  File.write(path, content)
end

When("I add the local file {string} with content {string}") do |path, content|
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, content)
end

When("I delete the local file {string}") do |path|
  FileUtils.rm(path)
end

Then("the S3 bucket {string} should contain:") do |path, table|
  s3_tree = Bard::Backup::S3Tree.new(path: path, **s3_credentials_for(path))
  objects = s3_tree.list_objects

  expected_keys = table.hashes.map { |row| row["key"] }.sort
  expect(objects.keys.sort).to eq(expected_keys)

  table.hashes.each do |row|
    body = s3_tree.get(row["key"])
    expect(body).to eq(row["content"])
  end
end

After do
  FileUtils.rm_rf("data") if Dir.exist?("data")
  FileUtils.rm_f(Bard::Backup::FileTree::MANIFEST_PATH)
  if @s3_tree
    @s3_tree.empty!
  end
end

def credentials
  @credentials ||= JSON.load_file("spec/support/credentials.json").transform_keys(&:to_sym)
end

def s3_credentials_for(path)
  bucket = path.split("/").first
  if bucket == "bard-data"
    project_name = path.split("/")[1]
    temp = assume_role_credentials(project_name)
    {
      access_key_id: temp.access_key_id,
      secret_access_key: temp.secret_access_key,
      session_token: temp.session_token,
      region: credentials[:region],
    }
  else
    credentials
  end
end

def assume_role_credentials(project_name)
  sts_client = Aws::STS::Client.new(
    region: credentials[:region],
    access_key_id: credentials[:access_key_id],
    secret_access_key: credentials[:secret_access_key],
  )
  session_policy = {
    "Version" => "2012-10-17",
    "Statement" => [{
      "Effect" => "Allow",
      "Action" => ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"],
      "Resource" => "arn:aws:s3:::bard-data/#{project_name}/*",
    }, {
      "Effect" => "Allow",
      "Action" => "s3:ListBucket",
      "Resource" => "arn:aws:s3:::bard-data",
      "Condition" => { "StringLike" => { "s3:prefix" => "#{project_name}/*" } },
    }],
  }
  response = sts_client.assume_role(
    role_arn: "arn:aws:iam::825043355522:role/bard-data-sync",
    role_session_name: "test-#{project_name}",
    duration_seconds: 900,
    policy: JSON.generate(session_policy),
  )
  response.credentials
end
