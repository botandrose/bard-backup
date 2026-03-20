Feature: Syncing file trees to S3
  Scenario: Initial sync uploads all local files
    Given the S3 bucket "bard-backup-test/test-file-tree" is empty
    And the local data directory "data/images" contains:
      | path       | content  |
      | cat.jpg    | catdata  |
      | dog.jpg    | dogdata  |
    And the local data directory "data/docs" contains:
      | path       | content  |
      | readme.txt | hello    |
    When I sync file trees for data paths "data/images,data/docs"
    Then the S3 bucket "bard-backup-test/test-file-tree" should contain:
      | key                  | content  |
      | data/images/cat.jpg  | catdata  |
      | data/images/dog.jpg  | dogdata  |
      | data/docs/readme.txt | hello    |

  Scenario: Sync with STS temporary credentials
    Given the S3 bucket "bard-data/test-file-tree-sts" is empty
    And the local data directory "data/images" contains:
      | path    | content |
      | cat.jpg | catdata |
    When I sync file trees for data paths "data/images" using STS credentials scoped to "test-file-tree-sts"
    Then the S3 bucket "bard-data/test-file-tree-sts" should contain:
      | key                 | content |
      | data/images/cat.jpg | catdata |

  Scenario: Incremental sync uploads only changes and deletes removed files
    Given the S3 bucket "bard-backup-test/test-file-tree" is empty
    And the local data directory "data/images" contains:
      | path       | content  |
      | cat.jpg    | catdata  |
      | dog.jpg    | dogdata  |
    And I sync file trees for data paths "data/images"
    When I update the local file "data/images/cat.jpg" with content "newcatdata"
    And I add the local file "data/images/bird.jpg" with content "birddata"
    And I delete the local file "data/images/dog.jpg"
    And I sync file trees for data paths "data/images"
    Then the S3 bucket "bard-backup-test/test-file-tree" should contain:
      | key                  | content     |
      | data/images/cat.jpg  | newcatdata  |
      | data/images/bird.jpg | birddata    |
