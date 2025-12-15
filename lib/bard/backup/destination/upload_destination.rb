require "fileutils"
require "uri"
require "net/http"

module Bard
  class Backup
    class Error < StandardError; end

    class UploadDestination < Destination
      def call
        timestamp = now
        filename = "#{timestamp.iso8601}.sql.gz"
        temp_path = "/tmp/#{filename}"
        errors = []

        begin
          Backhoe.dump(temp_path)
          size = File.size(temp_path)

          threads = urls.map do |url|
            Thread.new do
              upload_to_url(url, temp_path)
            rescue => e
              errors << e
            end
          end

          threads.each(&:join)
        ensure
          FileUtils.rm_f(temp_path)
        end

        raise Error, "Upload failed: #{errors.map(&:message).join(", ")}" unless errors.empty?

        Bard::Backup.new(timestamp:, size:, destinations: [])
      end

      def info
        { type: :upload, name: config[:name] }.compact
      end

      private

      def urls
        @urls ||= begin
          url_list = Array(config[:urls]).compact
          raise Error, "No URLs provided" if url_list.empty?
          url_list
        end
      end

      def upload_to_url(url, file_path)
        uri = URI.parse(url)

        File.open(file_path, "rb") do |file|
          request = Net::HTTP::Put.new(uri)
          request.body = file.read
          request.content_type = "application/octet-stream"

          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
            http.request(request)
          end

          unless response.is_a?(Net::HTTPSuccess)
            raise Error, "Upload failed with status #{response.code}: #{response.body}"
          end
        end
      end
    end
  end
end
