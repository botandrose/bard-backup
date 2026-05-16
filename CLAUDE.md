# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

bard-backup is a Ruby gem that provides automated backup for Bard projects. It:
- Dumps the database, uploads to S3, deletes old backups using a retention heuristic (48 hours, 30 days, 26 weeks, 24 months, then yearly), and verifies the previous hour's backup exists.
- Syncs configured data directories to S3 via a manifest-cached file tree (`Bard::Backup::FileTree`).
- Optionally encrypts uploaded payloads at rest with AES-256-GCM (`Bard::Backup::Encryptor`).

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

**Entry points**:
- `Bard::Backup.create!` accepts destination configs (or reads from `Bard::Config`) and delegates to destination strategies. Returns a `Bard::Backup` instance with timestamp/size/destinations.
- `Bard::Backup::FileTree.create!` syncs configured data directories to S3.

**Destination strategy pattern**: `Destination.build(config)` is a factory that picks the right class based on `:type`:
- `S3Destination` — dumps DB locally via backhoe, uploads to S3, runs `Deleter` for retention, verifies previous hour's backup
- `UploadDestination` — dumps DB and uploads to presigned URLs (multi-threaded)

**Config DSL** (loaded via `bard/plugins/backup` and `bard/plugins/encrypt`; `backup` extends `Bard::Config`, `encrypt` extends `Bard::BackupConfig`):
```ruby
backup do
  s3 "primary", path: "bucket/subfolder", region: "us-west-2"
  encrypt true  # reads key from config/master.key
end
```

**Key classes**:
- `S3Tree` — `Data.define`-based S3 wrapper used by both `S3Destination` and `FileTree`. Methods: `list_objects`, `put_file`, `put_body`, `get`, `delete_keys`, `mv`, `empty!`. Supports encryption via `Encryptor` and STS `session_token`.
- `FileTree` — syncs local data paths to S3 using a local `.bard-file-tree-sync.json` manifest (mtime+size fast path, MD5 verification, falls back to remote listing on first run)
- `Encryptor` — AES-256-GCM with HKDF-derived keys and a deterministic IV (HMAC of plaintext), enabling content-addressable encryption
- `Deleter` — implements the retention policy via `Filter` structs that check time-based granularities
- `LocalBackhoe` / `CachedLocalBackhoe` — database dump strategies (cached variant avoids conflicts when running parallel destinations)
- `LatestFinder` — finds the most recent backup across all configured destinations
- `BackupConfig` — the `backup do ... end` DSL surface (`bard`, `disabled`, `s3 name, **kwargs`); `create!` reads `bard_config.backup.destinations` from it
- `Railtie` — loads `tasks.rake` which provides `bard:backup` (DB + data) and `bard:backup:data` (data only) rake tasks in Rails apps
