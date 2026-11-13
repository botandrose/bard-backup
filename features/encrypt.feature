Feature: Encrypting backups stored before encryption was enabled
  Scenario: Encrypting existing database backups and data files
    Given the S3 bucket "bard-backup-test/test-encrypt-existing" contains these database backups:
      | 2024-07-25T11:00:00Z.sql.gz |
      | 2024-07-25T12:00:00Z.sql.gz |
    And the data file tree "bard-backup-test/test-encrypt-existing-data" contains in the clear:
      | key                 | content |
      | data/images/cat.jpg | catdata |
    When I encrypt the existing backups with key "test-master-key-0123456789abcdef"
    Then the S3 bucket "bard-backup-test/test-encrypt-existing" should contain encrypted:
      | key                         | content                          |
      | 2024-07-25T11:00:00Z.sql.gz | DUMP:2024-07-25T11:00:00Z.sql.gz |
      | 2024-07-25T12:00:00Z.sql.gz | DUMP:2024-07-25T12:00:00Z.sql.gz |
    And the S3 bucket "bard-backup-test/test-encrypt-existing-data" should contain encrypted:
      | key                 | content |
      | data/images/cat.jpg | catdata |
    When I restore the encrypted backup nearest "2024-07-25T12:00:00Z" with key "test-master-key-0123456789abcdef"
    Then the database should have been loaded from the "2024-07-25T12:00:00Z.sql.gz" backup
