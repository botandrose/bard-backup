# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

bard-backup is a Ruby gem that provides automated database backup for Bard projects. It dumps the database, uploads to S3, deletes old backups using a retention heuristic (48 hours, 30 days, 26 weeks, 24 months, then yearly), and verifies the previous hour's backup exists.

## Commands

```bash
# Run the default test suite (Cucumber acceptance tests)
bundle exec rake

# Run RSpec unit tests
bundle exec rspec

# Run a single spec file
bundle exec rspec spec/bard/backup/deleter_spec.rb

# Run Cucumber acceptance tests
bundle exec cucumber

# Run a specific Cucumber feature
bundle exec cucumber features/backup.feature
```

## Test Credentials

Tests require AWS credentials at `spec/support/credentials.json`. In CI, this is generated from GitHub secrets. For local development, create it manually:

```json
{
  "access_key_id": "...",
  "secret_access_key": "...",
  "region": "..."
}
```

## Architecture

**Entry point**: `Bard::Backup.create!` accepts destination configs (or reads from `Bard::Config`) and delegates to destination strategies. Returns a `Bard::Backup` instance with timestamp/size/destinations.

**Destination strategy pattern**: `Destination.build(config)` is a factory that picks the right class based on `:type`:
- `S3Destination` — dumps DB locally via backhoe, uploads to S3, runs `Deleter` for retention, verifies previous hour's backup
- `UploadDestination` — dumps DB and uploads to presigned URLs (multi-threaded)

**Key classes**:
- `S3Dir` — wraps `aws-sdk-s3` with `put`, `delete`, `files`, `empty!`, `mv`, `presigned_url`
- `Deleter` — implements the retention policy via `Filter` structs that check time-based granularities
- `LocalBackhoe` / `CachedLocalBackhoe` — database dump strategies (cached variant avoids conflicts when running parallel destinations)
- `LatestFinder` — finds the most recent backup across all configured destinations
- `Railtie` — loads `tasks.rake` which provides the `bard:backup` rake task in Rails apps
