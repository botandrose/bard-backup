def restore_destinations
  [{ type: :s3, path: @s3_tree.path, **credentials }]
end

Given("the S3 bucket {string} contains these database backups:") do |path, table|
  @s3_tree = Bard::Backup::S3Tree.new(path: namespaced(path), **credentials)
  @s3_tree.empty!
  @backup_bodies = {}
  table.raw.each do |filename, size|
    body = "DUMP:#{filename}"
    body = body.ljust(Integer(size)) if size
    @backup_bodies[filename] = body
    @s3_tree.put_body filename, body
  end
end

Given("the S3 bucket {string} contains an encrypted backup {string} with key {string}") do |path, filename, key|
  @encryption_key = key
  @s3_tree = Bard::Backup::S3Tree.new(path: namespaced(path), encryption_key: key, **credentials)
  @s3_tree.empty!
  @plaintext = "DUMP:#{filename}"
  @s3_tree.put_body filename, @plaintext
end

When("I list the available backups") do
  @listed = Bard::Backup.available(destinations: restore_destinations)
end

When("I restore the backup nearest {string}") do |at|
  @fake_backhoe = FakeBackhoe.new
  stub_const("Backhoe", @fake_backhoe)
  Bard::Backup.restore!(at: at, destinations: restore_destinations)
end

When("I restore the encrypted backup nearest {string} with key {string}") do |at, key|
  @fake_backhoe = FakeBackhoe.new
  stub_const("Backhoe", @fake_backhoe)
  Bard::Backup.restore!(at: at, destinations: [{ type: :s3, path: @s3_tree.path, encryption_key: key, **credentials }])
end

Then("the available backups should be:") do |table|
  actual = @listed.map { |backup| [backup.timestamp.iso8601, backup.size.to_s] }
  expect(actual).to eq(table.raw)
end

Then("the database should have been loaded from the {string} backup") do |filename|
  expect(@fake_backhoe.loaded_content).to eq(@backup_bodies.fetch(filename))
  expect(@fake_backhoe.loaded_drop_and_create).to eq(true)
end

Then("the loaded database content should be the unencrypted dump") do
  expect(@fake_backhoe.loaded_content).to eq(@plaintext)
end
