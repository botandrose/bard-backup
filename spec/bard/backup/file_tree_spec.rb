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
