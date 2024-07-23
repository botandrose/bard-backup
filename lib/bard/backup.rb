# frozen_string_literal: true

require "net/http"
require "openssl"
require "base64"
require "time"
require "backhoe"

module Bard
  class Backup < Struct.new(:s3_path, :filename, :access_key, :secret_key)
    def self.call s3_path, access_key:, secret_key:, filename: "#{Time.now.utc.iso8601}.sql.gz"
      new(s3_path, filename, access_key, secret_key).call
    end

    def call
      Backhoe.dump path

      self.full_s3_path = "/#{s3_path}/#{filename}"

      if s3_path.include?("/")
        s3_bucket = s3_path.split("/").first
        self.s3_path = s3_path.split("/")[1..].join("/")
        uri = URI("https://#{s3_bucket}.s3.amazonaws.com/#{s3_path}/#{filename}")
      else
        uri = URI("https://#{s3_path}.s3.amazonaws.com/#{filename}")
      end

      request = Net::HTTP::Put.new(uri, {
        "Content-Length": File.size(path).to_s,
        "Content-Type": content_type,
        "Date": date,
        "Authorization": "AWS #{access_key}:#{signature}",
        "x-amz-storage-class": "STANDARD",
        "x-amz-acl": "private",
      })
      request.body_stream = File.open(path)

      Net::HTTP.start(uri.hostname) do |http|
        response = http.request(request)
        response.value # raises if not success
      end
    end

    private

    attr_accessor :full_s3_path

    def signature
      digester = OpenSSL::Digest::SHA1.new
      digest = OpenSSL::HMAC.digest(digester, secret_key, key)
      Base64.strict_encode64(digest)
    end

    def key
      [
        "PUT",
        "",
        content_type,
        date,
        acl,
        storage_type,
        full_s3_path,
      ].join("\n")
    end

    def content_type
      "application/gzip"
    end

    def date
      Time.now.rfc2822
    end

    def acl
      "x-amz-acl:private"
    end

    def storage_type
      "x-amz-storage-class:STANDARD"
    end

    def path
      "/tmp/#{filename}"
    end
  end
end
