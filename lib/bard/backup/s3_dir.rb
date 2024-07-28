require "aws-sdk-s3"
require "rexml"

module Bard
  module Backup
    class S3Dir < Data.define(:path, :access_key, :secret_key, :region)
      def keys
        response = client.list_objects_v2({
          bucket: bucket_name,
          prefix: folder_prefix,
        })
        raise if response.is_truncated
        response.contents.map(&:key)
      end

      def put file_path, body: File.read(file_path)
        client.put_object({
          bucket: bucket_name,
          key: [folder_prefix, File.basename(file_path)].compact.join("/"),
          body: body,
        })
      end

      def delete keys
        return if keys.empty?
        objects_to_delete = Array(keys).map { |key| { key: key } }
        client.delete_objects({
          bucket: bucket_name,
          delete: {
            objects: objects_to_delete,
            quiet: true,
          }
        })
      end

      def empty!
        keys.each_slice(1000) do |key_batch|
          delete key_batch
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

      def client
        Aws::S3::Client.new({
          region: region,
          access_key_id: access_key,
          secret_access_key: secret_key,
        })
      end
    end
  end
end

