Given("the data file tree {string} contains in the clear:") do |path, table|
  @file_tree = Bard::Backup::S3Tree.new(path: namespaced(path), **credentials)
  @file_tree.empty!
  table.hashes.each { |row| @file_tree.put_body(row["key"], row["content"]) }
end

When("I encrypt the existing backups with key {string}") do |key|
  bucket, project_name = @file_tree.path.split("/", 2)
  Bard::Backup.encrypt_existing!(
    [{ type: :s3, path: @s3_tree.path, encryption_key: key, **credentials }],
    data_paths: ["data"],
    project_name:,
    bucket:,
    encryption_key: key,
    **credentials,
  )
end

After do
  @file_tree&.empty!
end
