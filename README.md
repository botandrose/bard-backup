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
end
```

Credentials live in Rails encrypted credentials under `bard_backup` (matched by `name:`):

```yaml
bard_backup:
  - name: primary
    access_key_id: ...
    secret_access_key: ...
    encryption_key: ...  # optional: encrypts payloads at rest with AES-256-GCM
```

Adding `encryption_key` is what turns on encryption at rest; omit it and payloads are stored
in the clear. Changing its value makes existing backups undecryptable, so treat it as
permanent unless you re-key deliberately.

Adding a key only encrypts what is uploaded afterwards. Database dumps stored before it still
restore (they are recognized as plain gzip), and `rake bard:backup:encrypt` rewrites them and
the data file tree in place under the key, verifying each object as it goes. It skips anything
already encrypted, so it is safe to rerun.

Then run via the rake tasks provided by the bundled Railtie:

```bash
rake bard:backup          # database backup + data file-tree sync
rake bard:backup:data     # data file-tree sync only
rake bard:backup:encrypt  # encrypt everything stored before encryption_key was added
```

## Restoring

Restore a database backup from S3 into the local database. The backup nearest the
requested timestamp is selected (backups run hourly, so an exact match isn't
guaranteed), downloaded, decrypted if necessary, and loaded via `backhoe`,
dropping and recreating the local database.

From the `bard` CLI:

```bash
bard backup restore                       # list the available backup timestamps
bard backup restore 2026-06-05T16:00:00Z  # restore the backup nearest this UTC time
```

Or via the rake task directly:

```bash
rake "bard:backup:restore"                       # list available backups
rake "bard:backup:restore[2026-06-05T16:00:00Z]" # restore nearest this time
```

Or programmatically:

```ruby
Bard::Backup.available                            # => [Time, Time, ...]
Bard::Backup.restore!                             # restore the latest backup
Bard::Backup.restore!(at: "2026-06-05T16:00:00Z") # restore nearest this time
```

Timestamps are UTC (the `Z`-suffixed ISO-8601 form the backups are named with).
Restore requires self-managed destinations configured via the `backup do ... end`
DSL; bard-managed backups are not yet supported.

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
