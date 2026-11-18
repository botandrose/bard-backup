require "pathname"

module Bard
  class Backup
    class UncoveredUploads < StandardError; end

    # Uploads on local disk are only backed up when bard.rb declares their directory as data.
    class UploadCoverage < Struct.new(:service, :data_paths)
      def self.check!(service = (ActiveStorage::Blob.service if defined?(ActiveStorage::Blob)), data_paths = Bard::Config.current.data)
        new(service, data_paths).check!
      end

      def check!
        return if service.nil? || covered?(service)
        roots = disk_roots(service).map { |root| display(root) }
        raise UncoveredUploads, "Active Storage keeps uploads on this server in #{roots.join(" and ")}, " \
          "which bard.rb does not declare as data, so they are not backed up. Add it to `data` in bard.rb."
      end

      private

      def covered?(service)
        if disk?(service)
          root = File.expand_path(service.root)
          data_paths.any? { |path| root == File.expand_path(path) || root.start_with?("#{File.expand_path(path)}/") }
        elsif mirror?(service)
          [service.primary, *service.mirrors].any? { |member| covered?(member) }
        else
          true
        end
      end

      def disk_roots(service)
        return [service.root] if disk?(service)
        return [service.primary, *service.mirrors].flat_map { |member| disk_roots(member) } if mirror?(service)
        []
      end

      def disk?(service)
        defined?(ActiveStorage::Service::DiskService) && service.is_a?(ActiveStorage::Service::DiskService)
      end

      def mirror?(service)
        defined?(ActiveStorage::Service::MirrorService) && service.is_a?(ActiveStorage::Service::MirrorService)
      end

      def display(root)
        relative = Pathname(File.expand_path(root)).relative_path_from(Dir.pwd).to_s
        relative.start_with?("..") ? root.to_s : relative
      end
    end
  end
end
