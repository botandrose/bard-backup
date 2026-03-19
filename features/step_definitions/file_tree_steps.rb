require "bard/backup/file_tree"
require "fileutils"

Given("the S3 bucket {string} is empty") do |path|
  @s3_tree = Bard::Backup::S3Tree.new(path: path, **credentials)
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
  s3_tree = Bard::Backup::S3Tree.new(path: path, **credentials)
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
