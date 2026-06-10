Feature: Restoring databases from S3
  Scenario: Listing the available backups
    Given the S3 bucket "bard-backup-test/test-restore" contains these database backups:
      | 2024-07-25T11:00:00Z.sql.gz |
      | 2024-07-25T12:00:00Z.sql.gz |
      | 2024-07-25T13:00:00Z.sql.gz |
    When I list the available backups
    Then the available backups should be:
      | 2024-07-25T11:00:00Z |
      | 2024-07-25T12:00:00Z |
      | 2024-07-25T13:00:00Z |

  Scenario: Restoring the backup nearest a timestamp
    Given the S3 bucket "bard-backup-test/test-restore" contains these database backups:
      | 2024-07-25T11:00:00Z.sql.gz |
      | 2024-07-25T12:00:00Z.sql.gz |
      | 2024-07-25T13:00:00Z.sql.gz |
    When I restore the backup nearest "2024-07-25T12:10:00Z"
    Then the database should have been loaded from the "2024-07-25T12:00:00Z.sql.gz" backup

  Scenario: Restoring an encrypted backup
    Given the S3 bucket "bard-backup-test/test-restore-encrypted" contains an encrypted backup "2024-07-25T12:00:00Z.sql.gz" with key "test-master-key-0123456789abcdef"
    When I restore the encrypted backup nearest "2024-07-25T12:00:00Z" with key "test-master-key-0123456789abcdef"
    Then the loaded database content should be the unencrypted dump
