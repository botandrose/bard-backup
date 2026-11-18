require "spec_helper"
require "bard/backup/file_tree"
require "tmpdir"
require "fileutils"

RSpec.describe Bard::Backup::FileTree do
  let(:s3_tree) { instance_double(Bard::Backup::S3Tree) }
  let(:data_paths) { ["data/images"] }
  let(:manifest_path) { Bard::Backup::FileTree::MANIFEST_PATH }

  subject { described_class.new(s3_tree, data_paths) }

  around do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        example.run
      end
    end
  end

  describe "#call" do
    context "first run (no manifest)" do
      before do
        FileUtils.mkdir_p("data/images")
        File.write("data/images/cat.jpg", "catdata")
        allow(s3_tree).to receive(:list_objects).and_return({})
        allow(s3_tree).to receive(:etag_for) { |path| Digest::MD5.file(path).hexdigest }
        allow(s3_tree).to receive(:put_file)
        allow(s3_tree).to receive(:delete_keys)
      end

      it "uploads all local files" do
        subject.call
        expect(s3_tree).to have_received(:put_file).with("data/images/cat.jpg", "data/images/cat.jpg")
      end

      it "skips files that already exist on S3 with matching MD5" do
        md5 = Digest::MD5.hexdigest("catdata")
        allow(s3_tree).to receive(:list_objects).and_return({ "data/images/cat.jpg" => md5 })

        subject.call
        expect(s3_tree).not_to have_received(:put_file)
      end

      it "deletes S3 files not found locally" do
        allow(s3_tree).to receive(:list_objects).and_return({ "data/images/old.jpg" => "abc123" })

        subject.call
        expect(s3_tree).to have_received(:delete_keys).with(["data/images/old.jpg"])
      end

      it "saves a manifest" do
        subject.call
        expect(File.exist?(manifest_path)).to be true
        manifest = JSON.parse(File.read(manifest_path))
        expect(manifest).to have_key("data/images/cat.jpg")
        expect(manifest["data/images/cat.jpg"]["md5"]).to eq Digest::MD5.hexdigest("catdata")
      end
    end

    context "first run (no manifest) with encryption" do
      let(:client) { Aws::S3::Client.new(stub_responses: true) }
      let(:s3_tree) do
        Bard::Backup::S3Tree.new(path: "bard-data/project", access_key_id: "a", secret_access_key: "b", region: "us-west-2", encryption_key: "key")
      end

      before do
        FileUtils.mkdir_p("data/images")
        File.write("data/images/cat.jpg", "catdata")
        File.write("data/images/dog.jpg", "dogdata")
        ciphertext_md5 = Digest::MD5.hexdigest(Bard::Backup::Encryptor.new("key").encrypt("catdata"))
        client.stub_responses(:list_objects_v2, contents: [{ key: "project/data/images/cat.jpg", etag: %("#{ciphertext_md5}") }])
        allow(Aws::S3::Client).to receive(:new).and_return(client)
      end

      it "uploads only the files whose ciphertext is not already on S3" do
        subject.call
        uploads = client.api_requests.select { |request| request[:operation_name] == :put_object }
        expect(uploads.map { |request| request[:params][:key] }).to eq ["project/data/images/dog.jpg"]
      end
    end

    context "while another sync is running" do
      before do
        FileUtils.mkdir_p("data/images")
        File.write("data/images/cat.jpg", "catdata")
        allow(s3_tree).to receive(:list_objects)
      end

      it "leaves the sync to the run already in progress" do
        File.open("#{manifest_path}.lock", File::CREAT | File::RDWR) do |lock|
          lock.flock(File::LOCK_EX)
          subject.call
        end
        expect(s3_tree).not_to have_received(:list_objects)
        expect(File.exist?(manifest_path)).to be false
      end
    end

    context "with SQLite databases in a data path" do
      let(:data_paths) { ["storage"] }
      let(:solid_files) do
        %w[
          storage/production_queue.sqlite3 storage/production_queue.sqlite3-wal storage/production_queue.sqlite3-shm
          storage/app_production_cache.sqlite3 storage/production_cable.sqlite3-journal
          storage/production.sqlite3 storage/production.sqlite3-wal
        ]
      end

      before do
        FileUtils.mkdir_p("storage/ab/cd")
        File.write("storage/ab/cd/abcdblob", "upload")
        File.write("storage/queue-photo.sqlite3.jpg", "upload")
        solid_files.each { |file| File.write(file, "state") }
        allow(s3_tree).to receive(:list_objects).and_return({ "storage/production_queue.sqlite3" => "abc123" })
        allow(s3_tree).to receive(:etag_for) { |path| Digest::MD5.file(path).hexdigest }
        allow(s3_tree).to receive(:put_file)
        allow(s3_tree).to receive(:delete_keys)
      end

      it "syncs the uploads but not the databases, and removes databases synced before" do
        subject.call
        expect(s3_tree).to have_received(:put_file).with("storage/ab/cd/abcdblob", "storage/ab/cd/abcdblob")
        expect(s3_tree).to have_received(:put_file).with("storage/queue-photo.sqlite3.jpg", "storage/queue-photo.sqlite3.jpg")
        solid_files.each { |file| expect(s3_tree).not_to have_received(:put_file).with(file, anything) }
        expect(s3_tree).to have_received(:delete_keys).with(["storage/production_queue.sqlite3"])
      end
    end

    context "subsequent run (manifest exists)" do
      before do
        FileUtils.mkdir_p("data/images")
        File.write("data/images/cat.jpg", "catdata")

        stat = File.stat("data/images/cat.jpg")
        manifest = {
          "data/images/cat.jpg" => {
            "md5" => Digest::MD5.hexdigest("catdata"),
            "mtime" => stat.mtime.to_f,
            "size" => stat.size,
          },
        }
        File.write(manifest_path, JSON.pretty_generate(manifest))

        allow(s3_tree).to receive(:put_file)
        allow(s3_tree).to receive(:delete_keys)
      end

      it "skips unchanged files" do
        subject.call
        expect(s3_tree).not_to have_received(:put_file)
      end

      it "uploads files with changed content" do
        File.write("data/images/cat.jpg", "newcatdata")

        subject.call
        expect(s3_tree).to have_received(:put_file).with("data/images/cat.jpg", "data/images/cat.jpg")
      end

      it "uploads new files" do
        File.write("data/images/dog.jpg", "dogdata")

        subject.call
        expect(s3_tree).to have_received(:put_file).with("data/images/dog.jpg", "data/images/dog.jpg")
      end

      it "deletes files removed locally" do
        FileUtils.rm("data/images/cat.jpg")

        subject.call
        expect(s3_tree).to have_received(:delete_keys).with(["data/images/cat.jpg"])
      end
    end
  end
end
