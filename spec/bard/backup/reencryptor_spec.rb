require "spec_helper"
require "bard/backup/reencryptor"
require "bard/backup/encryptor"

RSpec.describe Bard::Backup::Reencryptor do
  # An in-memory stand-in for S3Tree: same files/get/put_body surface, encrypting exactly
  # like the real tree does (via the real Encryptor) so the round-trip is genuine crypto.
  class FakeTree
    def initialize(bucket, key)
      @bucket = bucket
      @encryptor = Bard::Backup::Encryptor.new(key)
    end

    def files
      @bucket.keys
    end

    def get(key)
      @encryptor.decrypt(@bucket.fetch(key))
    end

    def put_body(key, body)
      @bucket[key] = @encryptor.encrypt(body)
    end
  end

  let(:old_key) { "old-master-key-0123456789abcdef" }
  let(:new_key) { "new-master-key-0123456789abcdef" }

  describe "#reencrypt" do
    it "rewrites each object so the new key decrypts and the old key no longer can" do
      bucket = {}
      seed = FakeTree.new(bucket, old_key)
      seed.put_body("2026-07-12.sql.gz", "dump-A")
      seed.put_body("files/logo.png", "img-B")

      rewritten = described_class.new(old_key: old_key, new_key: new_key)
        .reencrypt(FakeTree.new(bucket, old_key), FakeTree.new(bucket, new_key))

      expect(rewritten).to contain_exactly("2026-07-12.sql.gz", "files/logo.png")
      expect(FakeTree.new(bucket, new_key).get("2026-07-12.sql.gz")).to eq("dump-A")
      expect(FakeTree.new(bucket, new_key).get("files/logo.png")).to eq("img-B")
      expect { FakeTree.new(bucket, old_key).get("files/logo.png") }
        .to raise_error(OpenSSL::Cipher::CipherError)
    end

    it "is a no-op on an empty destination" do
      expect(described_class.new(old_key: old_key, new_key: new_key)
        .reencrypt(FakeTree.new({}, old_key), FakeTree.new({}, new_key))).to eq([])
    end
  end

  describe "#call" do
    it "builds an old-key and new-key tree for the same connection config" do
      config = { path: "bucket/folder", region: "us-west-2" }
      old_tree = instance_double("old")
      new_tree = instance_double("new")
      expect(Bard::Backup::S3Tree).to receive(:new).with(**config, encryption_key: old_key).and_return(old_tree)
      expect(Bard::Backup::S3Tree).to receive(:new).with(**config, encryption_key: new_key).and_return(new_tree)

      reencryptor = described_class.new(old_key: old_key, new_key: new_key)
      expect(reencryptor).to receive(:reencrypt).with(old_tree, new_tree).and_return(["x"])
      expect(reencryptor.call(config)).to eq(["x"])
    end
  end
end

RSpec.describe "Bard::Backup.reencrypt!" do
  it "re-encrypts only S3 destinations, passing each one's connection config" do
    s3 = double("s3 destination", s3_tree_config: { path: "bucket" })
    upload = double("upload destination") # no s3_tree_config -> skipped
    allow(Bard::Backup::Destination).to receive(:resolve).with(nil).and_return([s3, upload])
    allow_any_instance_of(Bard::Backup::Reencryptor).to receive(:call).with({ path: "bucket" }).and_return(["a", "b"])

    expect(Bard::Backup.reencrypt!(old_key: "o", new_key: "n")).to eq(["a", "b"])
  end
end
