module Bard
  class Backup
    module RailsCredentials
      def self.find(name: nil)
        entries = all
        return {} if entries.empty?
        return entries.first if name.nil?
        entries.find { |c| c[:name] == name } || {}
      end

      def self.all
        return [] unless defined?(Rails)
        creds = Rails.application.credentials.bard_backup
        return [] unless creds
        creds.is_a?(Hash) ? [creds] : Array(creds)
      end
    end
  end
end
