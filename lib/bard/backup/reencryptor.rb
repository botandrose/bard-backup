require "bard/backup/s3_tree"

module Bard
  class Backup
    # Rewrites every backup object under a destination from an old encryption key to a new
    # one: get() decrypts with the old key, put_body() re-encrypts with the new, writing back
    # to the same S3 key (in place). The backup encryption key IS the app's master key, so
    # when `bard rotate` changes the master key this is what keeps existing backups readable —
    # without it, every prior backup would be undecryptable under the new key.
    class Reencryptor
      def initialize(old_key:, new_key:)
        @old_key = old_key
        @new_key = new_key
      end

      def call(tree_config)
        reencrypt(
          S3Tree.new(**tree_config, encryption_key: @old_key),
          S3Tree.new(**tree_config, encryption_key: @new_key),
        )
      end

      # Split out so the rewrite loop is unit-testable against in-memory trees.
      def reencrypt(old_tree, new_tree)
        old_tree.files.map do |file|
          new_tree.put_body(file, old_tree.get(file))
          file
        end
      end
    end
  end
end
