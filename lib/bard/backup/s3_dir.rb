require "aws-sdk-s3"
require "rexml"

class S3Dir < Data.define(:path, :access_key, :secret_key)
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
      key: "#{folder_prefix}/#{File.basename(file_path)}",
      body: body,
    })
  end

  def empty!
    keys.each_slice(1000) do |key_batch|
      objects_to_delete = key_batch.map { |key| { key: key } }
      client.delete_objects({
        bucket: bucket_name,
        delete: {
          objects: objects_to_delete,
          quiet: true,
        }
      })
    end
  end

  def bucket_name
    path.split("/").first
  end

  def folder_prefix
    path.split("/")[1..].join("/")
  end

  private

  def client
    Aws::S3::Client.new({
      region: "us-west-2",
      access_key_id: access_key,
      secret_access_key: secret_key,
    })
  end
end


