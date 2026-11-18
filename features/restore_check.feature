Feature: Checking that the latest backup restores
  Scenario: Restoring the latest backup into a scratch database and checking its tables
    Given the live database has a "users" table with 7 rows
    And the S3 bucket "bard-backup-test/test-restore-check" holds a backup at "2024-07-25T11:00:00Z" of a database with no tables
    And it holds a backup at "2024-07-25T12:00:00Z" of a database with these tables:
      | table             | rows |
      | schema_migrations | 1    |
      | users             | 3    |
      | posts             | 0    |
    When I check that the latest backup restores
    Then the restore check should report "Restore check passed for backup 2024-07-25T12:00:00Z: 3 tables, 4 rows"
    And the scratch database should be gone
    And the live database should still have a "users" table with 7 rows
