Feature: Backing up databases to S3
  Scenario: Uploading a new dump to the bucket
    Given the S3 bucket "bard-backup-test/test" contains the backups from "features/fixtures/before_files.txt"
    When I run the backup at "2024-07-25T12:00:03Z"
    Then the bucket should contain the backups from "features/fixtures/after_files.txt"
