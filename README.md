# Bard::Backup

Bard::Backup does 3 things in a bard project
1. Takes a database dump and uploads it to our s3 bucket
2. Deletes old backups using a backoff heuristic: 48 hours, 30 days, 26 weeks, 24 months, then yearly
3. Raises an error if we don't have a backup from the previous hour

## Installation

## Usage

Run with `Bard::Backup.call path: "s3_bucket/optional_subfolder", access_key: "...", secret_key: "...", region: "..."`

Or just run via the `bard-rake` gem: `rake db:backup`, which wires up the above for you.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/bard-backup.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
