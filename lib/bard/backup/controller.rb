module Bard
  module Backup
    class Controller < Struct.new(:dumper, :s3_dir, :now)
      def call
        filename = "#{now.iso8601}.sql.gz"
        path = "/tmp/#{filename}"
        dumper.dump path
        s3_dir.put path
      end
    end
  end
end
