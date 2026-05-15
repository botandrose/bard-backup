require "aws-sdk-s3"
require "fileutils"
require "bard/backup/encryptor"

module Bard
  class Backup
    class S3Tree < Data.define(:endpoint, :path, :access_key_id, :secret_access_key, :region, :session_token, :encryption_key)
      def initialize(**kwargs)
        kwargs[:endpoint] ||= "https://s3.#{kwargs[:region]}.amazonaws.com"
        kwargs[:session_token] ||= nil
        kwargs[:encryption_key] ||= nil
        super
      end

      def list_objects
        result = {}
        continuation_token = nil

        loop do
          response = client.list_objects_v2({
            bucket: bucket_name,
            prefix: folder_prefix ? "#{folder_prefix}/" : nil,
            continuation_token: continuation_token,
          }.compact)

          response.contents.each do |object|
            key = folder_prefix ? object.key.sub("#{folder_prefix}/", "") : object.key
            result[key] = object.etag.tr('"', "")
          end

          break unless response.is_truncated
          continuation_token = response.next_continuation_token
        end

        result
      end

      def put_file(local_path, remote_key)
        put_body(remote_key, File.binread(local_path))
      end

      def put_body(remote_key, body)
        body = encryptor.encrypt(body) if encryptor
        client.put_object({
          bucket: bucket_name,
          key: [folder_prefix, remote_key].compact.join("/"),
          body: body,
        })
      end

      def mv(local_path)
        put_file(local_path, File.basename(local_path))
        FileUtils.rm(local_path)
      end

      def get(remote_key)
        response = client.get_object({
          bucket: bucket_name,
          key: [folder_prefix, remote_key].compact.join("/"),
        })
        body = response.body.read
        body = encryptor.decrypt(body) if encryptor
        body
      end

      def delete_keys(keys)
        return if keys.empty?
        keys.each_slice(1000) do |batch|
          objects_to_delete = batch.map do |key|
            { key: [folder_prefix, key].compact.join("/") }
          end
          client.delete_objects({
            bucket: bucket_name,
            delete: {
              objects: objects_to_delete,
              quiet: true,
            },
          })
        end
      end

      def empty!
        list_objects.keys.each_slice(1000) do |batch|
          delete_keys(batch)
        end
      end

      def bucket_name
        path.split("/").first
      end

      def folder_prefix
        return nil if !path.include?("/")
        path.split("/")[1..].join("/")
      end

      private

      def encryptor
        Encryptor.new(encryption_key) if encryption_key
      end

      def client
        Aws::S3::Client.new({
          endpoint: endpoint,
          region: region,
          access_key_id: access_key_id,
          secret_access_key: secret_access_key,
          session_token: session_token,
        }.compact)
      end
    end
  end
end
