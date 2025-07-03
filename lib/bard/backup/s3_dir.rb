require "aws-sdk-s3"
require "rexml"

module Bard
  class Backup
    class S3Dir < Data.define(:endpoint, :path, :access_key, :secret_key, :region)
      def initialize **kwargs
        kwargs[:endpoint] ||= "https://s3.#{kwargs[:region]}.amazonaws.com"
        super
      end

      def files
        response = client.list_objects_v2({
          bucket: bucket_name,
          prefix: folder_prefix,
        })
        raise if response.is_truncated
        response.contents.map do |object|
          object.key.sub("#{folder_prefix}/", "")
        end
      end

      def put file_path, body: File.read(file_path)
        client.put_object({
          bucket: bucket_name,
          key: [folder_prefix, File.basename(file_path)].compact.join("/"),
          body: body,
        })
      end

      def presigned_url file_path
        presigner = Aws::S3::Presigner.new(client: client)
        presigner.presigned_url(
          :put_object,
          bucket: bucket_name,
          key: [folder_prefix, File.basename(file_path)].compact.join("/"),
        )
      end

      def mv file_path, body: File.read(file_path)
        put file_path, body: body
        FileUtils.rm file_path
      end

      def delete file_paths
        return if file_paths.empty?
        objects_to_delete = Array(file_paths).map do |file_path|
          { key: [folder_prefix, File.basename(file_path)].compact.join("/") }
        end
        client.delete_objects({
          bucket: bucket_name,
          delete: {
            objects: objects_to_delete,
            quiet: true,
          }
        })
      end

      def empty!
        files.each_slice(1000) do |batch|
          delete batch
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
          endpoint: endpoint,
          region: region,
          access_key_id: access_key,
          secret_access_key: secret_key,
        })
      end
    end
  end
end
