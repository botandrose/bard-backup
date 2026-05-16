# Bard::Backup

Bard::Backup handles backups for a bard project:
1. Takes a database dump and uploads it to S3 (or PUTs it to presigned URLs)
2. Syncs configured data directories to S3 with a local manifest cache
3. Deletes old database backups using a backoff heuristic: 48 hours, 30 days, 26 weeks, 24 months, then yearly
4. Raises an error if we don't have a database backup from the previous hour
5. Optionally encrypts uploaded payloads at rest with AES-256-GCM

## Installation

Add to your `Gemfile`:

```ruby
gem "bard-backup"
```

## Usage

In a Rails app, configure destinations in `config/bard.rb` using the `Bard::Config` DSL:

```ruby
backup do
  s3 "primary", path: "my-bucket/my-project", region: "us-west-2"
  encrypt true  # optional: encrypt payloads at rest. Reads key from config/master.key.
end
```

Credentials live in Rails encrypted credentials under `bard_backup` (matched by `name:`):

```yaml
bard_backup:
  - name: primary
    access_key_id: ...
    secret_access_key: ...
```

Then run via the rake tasks provided by the bundled Railtie:

```bash
rake bard:backup        # database backup + data file-tree sync
rake bard:backup:data   # data file-tree sync only
```

Or call programmatically:

```ruby
Bard::Backup.create!(type: :s3, path: "bucket/subfolder",
                     access_key_id: "...", secret_access_key: "...", region: "...")
Bard::Backup::FileTree.create!
```

`UploadDestination` (`type: :upload`, with `urls: [...]`) PUTs the dump to one or more presigned URLs in parallel — useful when the receiver, not the sender, holds the S3 credentials.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/botandrose/bard-backup.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
