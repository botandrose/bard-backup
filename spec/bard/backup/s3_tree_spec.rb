require "bard/backup/s3_tree"

RSpec.describe Bard::Backup::S3Tree do
  let(:access_key_id) { "abc" }
  let(:secret_access_key) { "123" }
  let(:region) { "usa" }

  describe "#bucket_name" do
    it "is the first part of the path" do
      subject = described_class.new(path: "bard-data/my-project", access_key_id:, secret_access_key:, region:)
      expect(subject.bucket_name).to eq "bard-data"
    end

    it "is the whole path if no subdirectory" do
      subject = described_class.new(path: "bard-data", access_key_id:, secret_access_key:, region:)
      expect(subject.bucket_name).to eq "bard-data"
    end
  end

  describe "#folder_prefix" do
    it "is the rest of the path after bucket name" do
      subject = described_class.new(path: "bard-data/my-project", access_key_id:, secret_access_key:, region:)
      expect(subject.folder_prefix).to eq "my-project"
    end

    it "supports nested paths" do
      subject = described_class.new(path: "bard-data/my-project/sub", access_key_id:, secret_access_key:, region:)
      expect(subject.folder_prefix).to eq "my-project/sub"
    end

    it "is nil if no subdirectory" do
      subject = described_class.new(path: "bard-data", access_key_id:, secret_access_key:, region:)
      expect(subject.folder_prefix).to be_nil
    end
  end

  describe "#files" do
    it "returns the keys of list_objects" do
      stub_client = Aws::S3::Client.new(stub_responses: true)
      stub_client.stub_responses(:list_objects_v2, contents: [
        { key: "my-project/a.sql.gz", etag: '"etag-a"' },
        { key: "my-project/b.sql.gz", etag: '"etag-b"' },
      ])
      allow(Aws::S3::Client).to receive(:new).and_return(stub_client)

      subject = described_class.new(path: "bard-data/my-project", access_key_id:, secret_access_key:, region:)
      expect(subject.files).to eq ["a.sql.gz", "b.sql.gz"]
    end
  end

  describe "#presigned_url" do
    let(:stub_client) do
      Aws::S3::Client.new(
        stub_responses: true,
        access_key_id:,
        secret_access_key:,
        region: "us-west-2",
      )
    end

    before { allow(Aws::S3::Client).to receive(:new).and_return(stub_client) }

    it "builds a presigned PUT URL for a file in the folder prefix" do
      subject = described_class.new(path: "bard-data/my-project", access_key_id:, secret_access_key:, region: "us-west-2")
      url = subject.presigned_url("2024-07-25T12:00:03Z.sql.gz")
      expect(url).to include("bard-data.s3")
      expect(url).to include("my-project/2024-07-25T12%3A00%3A03Z.sql.gz")
      expect(url).to include("X-Amz-Signature=")
    end

    it "omits folder prefix when path is just a bucket" do
      subject = described_class.new(path: "bard-data", access_key_id:, secret_access_key:, region: "us-west-2")
      url = subject.presigned_url("dump.sql.gz")
      expect(url).to include("bard-data.s3")
      expect(url).to include("/dump.sql.gz?")
    end
  end

  describe "#get" do
    let(:key) { "test-master-key-0123456789abcdef" }
    subject(:tree) { described_class.new(path: "bard-backup/my-project", access_key_id:, secret_access_key:, region:, encryption_key: key) }

    def stub_body(body)
      stub_client = Aws::S3::Client.new(stub_responses: true)
      stub_client.stub_responses(:get_object, body: body)
      allow(Aws::S3::Client).to receive(:new).and_return(stub_client)
    end

    it "decrypts with the encryption key" do
      stub_body(Bard::Backup::Encryptor.new(key).encrypt("\x1f\x8bdump".b))
      expect(tree.get("a.sql.gz")).to eq("\x1f\x8bdump".b)
    end

    it "returns a gzip dump stored before encryption was enabled as-is" do
      stub_body("\x1f\x8bplain dump".b)
      expect(tree.get("a.sql.gz")).to eq("\x1f\x8bplain dump".b)
    end

    it "still raises on anything else that does not decrypt" do
      stub_body(Bard::Backup::Encryptor.new("wrong-key-0123456789abcdefghij").encrypt("dump"))
      expect { tree.get("a.sql.gz") }.to raise_error(OpenSSL::Cipher::CipherError)
    end
  end
end
