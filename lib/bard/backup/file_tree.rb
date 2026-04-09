require "json"
require "digest/md5"
require "bard/backup/s3_tree"

module Bard
  class Backup
    class FileTree
      MANIFEST_PATH = ".bard-file-tree-sync.json"
      DEFAULT_BUCKET = "bard-data"

      def self.create!(data_paths: nil, project_name: nil, bucket: DEFAULT_BUCKET, **s3_config)
        bard_config = defined?(Bard::Config) ? Bard::Config.current : nil
        data_paths ||= bard_config&.data || []
        project_name ||= bard_config&.project_name
        return if data_paths.empty?

        if s3_config.empty? && defined?(Rails)
          credentials = Rails.application.credentials.bard_backup || []
          credentials = [credentials] if credentials.is_a?(Hash)
          s3_config = credentials.first&.slice(:access_key_id, :secret_access_key, :region) || {}
        end

        encryption_key = s3_config.delete(:encryption_key)
        encryption_key ||= bard_config&.respond_to?(:encryption_key) ? bard_config.encryption_key : nil

        s3_tree = S3Tree.new(path: "#{bucket}/#{project_name}", encryption_key: encryption_key, **s3_config)
        new(s3_tree, data_paths).call
      end

      def initialize(s3_tree, data_paths)
        @s3_tree = s3_tree
        @data_paths = data_paths
      end

      def call
        manifest = load_manifest
        local_files = collect_local_files

        if manifest.empty?
          sync_from_s3(local_files)
        else
          sync_from_manifest(local_files, manifest)
        end
      end

      private

      attr_reader :s3_tree, :data_paths

      def sync_from_manifest(local_files, manifest)
        new_manifest = {}

        local_files.each do |path, stat|
          cached = manifest[path]
          if cached && cached["mtime"] == stat[:mtime] && cached["size"] == stat[:size]
            new_manifest[path] = cached
          else
            md5 = Digest::MD5.file(path).hexdigest
            if cached && cached["md5"] == md5
              new_manifest[path] = cached.merge("mtime" => stat[:mtime])
            else
              s3_tree.put_file(path, path)
              new_manifest[path] = { "md5" => md5, "mtime" => stat[:mtime], "size" => stat[:size] }
            end
          end
        end

        removed = manifest.keys - local_files.keys
        s3_tree.delete_keys(removed)

        save_manifest(new_manifest)
      end

      def sync_from_s3(local_files)
        remote = s3_tree.list_objects
        new_manifest = {}

        local_files.each do |path, stat|
          md5 = Digest::MD5.file(path).hexdigest
          unless remote[path] == md5
            s3_tree.put_file(path, path)
          end
          new_manifest[path] = { "md5" => md5, "mtime" => stat[:mtime], "size" => stat[:size] }
        end

        removed = remote.keys - local_files.keys
        s3_tree.delete_keys(removed)

        save_manifest(new_manifest)
      end

      def collect_local_files
        result = {}
        data_paths.each do |data_path|
          Dir.glob("#{data_path}/**/*").each do |file|
            next unless File.file?(file)
            stat = File.stat(file)
            result[file] = { mtime: stat.mtime.to_f, size: stat.size }
          end
        end
        result
      end

      def load_manifest
        return {} unless File.exist?(MANIFEST_PATH)
        JSON.parse(File.read(MANIFEST_PATH))
      end

      def save_manifest(manifest)
        File.write(MANIFEST_PATH, JSON.pretty_generate(manifest))
      end
    end
  end
end
