require "bard/backup/s3_tree"
require "bard/backup/encryptor"
require "bard/backup/destination"

module Bard
  class Backup
    class Rekey < Struct.new(:tree_config, :to_key, :from_key, keyword_init: true)
      def self.call(...)
        new(...).call
      end

      def call
        result = { path: tree_config[:path], encrypted: [], skipped: [], gone: [] }
        stored_tree.files.each do |file|
          stored = begin
            stored_tree.get(file).b
          rescue Aws::S3::Errors::NoSuchKey
            # the hourly backup pruned it after we listed it
            result[:gone] << file
            next
          end
          if under_target_key?(stored)
            result[:skipped] << file
          else
            rewrite(file, stored)
            result[:encrypted] << file
          end
        end
        result
      end

      private

      def rewrite(file, stored)
        body = from_key ? Encryptor.new(from_key).decrypt(stored) : stored
        target_tree.put_body(file, body)
        return if reads_back?(file, body)

        stored_tree.put_body(file, stored)
        raise Error, "#{file} did not read back intact after encrypting, so its original was put back"
      end

      def reads_back?(file, body)
        target_tree.get(file).b == body
      rescue OpenSSL::Cipher::CipherError
        false
      end

      def under_target_key?(stored)
        target_encryptor.decrypt(stored)
        true
      rescue OpenSSL::Cipher::CipherError
        false
      end

      def stored_tree
        @stored_tree ||= S3Tree.new(**tree_config)
      end

      def target_tree
        @target_tree ||= S3Tree.new(**tree_config, encryption_key: to_key)
      end

      def target_encryptor
        @target_encryptor ||= Encryptor.new(to_key)
      end
    end
  end
end
