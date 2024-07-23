module Bard
  module Backup
    class Controller < Struct.new(:dumper, :s3_dir, :filename)
      def call
        path = "/tmp/#{filename}"
        dumper.dump path
        s3_dir.put path
      end
    end
  end
end
