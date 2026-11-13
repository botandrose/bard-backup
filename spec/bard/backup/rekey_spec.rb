require "spec_helper"

RSpec.describe Bard::Backup::Rekey do
  let(:key) { "test-master-key-0123456789abcdef" }
  let(:old_key) { "old-master-key-0123456789abcdef" }
  let(:tree_config) { { path: "bucket/project", access_key_id: "abc", secret_access_key: "123", region: "us-west-2" } }
  let(:bucket) { {} }
  let(:puts_seen) { [] }
  let(:listed_but_gone) { [] }

  before do
    client = Aws::S3::Client.new(stub_responses: true)
    client.stub_responses(:put_object, ->(context) {
      puts_seen << context.params[:key]
      bucket[context.params[:key]] = context.params[:body].b
      {}
    })
    client.stub_responses(:get_object, ->(context) { bucket.key?(context.params[:key]) ? { body: bucket[context.params[:key]] } : "NoSuchKey" })
    client.stub_responses(:list_objects_v2, ->(context) {
      { contents: (bucket.keys + listed_but_gone).map { |key| { key:, etag: %("etag") } }, is_truncated: false }
    })
    allow(Aws::S3::Client).to receive(:new).and_return(client)
  end

  def stored(name) = bucket.fetch("project/#{name}")
  def store(name, body) = bucket["project/#{name}"] = body.b
  def decrypt(name, with: key) = Bard::Backup::Encryptor.new(with).decrypt(stored(name))

  it "encrypts plaintext objects in place and reports them" do
    store("2024-07-25T12:00:00Z.sql.gz", "\x1f\x8bdump \xff".b)
    store("data/cat.jpg", "catdata")

    result = described_class.call(tree_config:, to_key: key)

    expect(result).to eq(path: "bucket/project", encrypted: ["2024-07-25T12:00:00Z.sql.gz", "data/cat.jpg"], skipped: [], gone: [])
    expect(decrypt("2024-07-25T12:00:00Z.sql.gz")).to eq("\x1f\x8bdump \xff".b)
    expect(decrypt("data/cat.jpg")).to eq("catdata")
  end

  it "skips an object that disappears mid-run, as when the hourly backup prunes an old dump" do
    store("a.sql.gz", "\x1f\x8bdump".b)
    listed_but_gone << "project/2024-07-25T11:00:00Z.sql.gz"

    result = described_class.call(tree_config:, to_key: key)

    expect(result).to eq(path: "bucket/project", encrypted: ["a.sql.gz"], skipped: [], gone: ["2024-07-25T11:00:00Z.sql.gz"])
    expect(bucket.keys).to eq(["project/a.sql.gz"])
  end

  it "leaves objects already encrypted under the key alone, so a rerun is a no-op" do
    store("a.sql.gz", Bard::Backup::Encryptor.new(key).encrypt("dump"))

    result = described_class.call(tree_config:, to_key: key)

    expect(result).to eq(path: "bucket/project", encrypted: [], skipped: ["a.sql.gz"], gone: [])
    expect(puts_seen).to be_empty
  end

  it "treats objects too short to be ciphertext as plaintext" do
    store("tiny.txt", "hi")

    described_class.call(tree_config:, to_key: key)

    expect(decrypt("tiny.txt")).to eq("hi")
  end

  it "re-keys objects encrypted under a previous key" do
    store("a.sql.gz", Bard::Backup::Encryptor.new(old_key).encrypt("dump"))

    described_class.call(tree_config:, to_key: key, from_key: old_key)

    expect(decrypt("a.sql.gz")).to eq("dump")
  end

  it "refuses an object under neither key rather than encrypting it twice" do
    store("a.sql.gz", Bard::Backup::Encryptor.new("some-other-key-0123456789abcd").encrypt("dump"))

    expect { described_class.call(tree_config:, to_key: key, from_key: old_key) }
      .to raise_error(OpenSSL::Cipher::CipherError)
    expect(puts_seen).to be_empty
  end

  it "puts the original back and stops when the rewritten object does not read back intact" do
    store("a.sql.gz", "\x1f\x8bdump".b)
    store("b.sql.gz", "\x1f\x8bother".b)
    allow_any_instance_of(Bard::Backup::Encryptor).to receive(:encrypt).and_wrap_original do |original, body|
      original.call(body)[0..-2]
    end

    expect { described_class.call(tree_config:, to_key: key) }
      .to raise_error(Bard::Backup::Error, /a\.sql\.gz/)
    expect(stored("a.sql.gz")).to eq("\x1f\x8bdump".b)
    expect(stored("b.sql.gz")).to eq("\x1f\x8bother".b)
  end
end

RSpec.describe "Bard::Backup.encrypt_existing!" do
  it "refuses a destination that has no encryption key" do
    expect {
      Bard::Backup.encrypt_existing!([{ name: "primary", type: :s3, path: "bucket/project", region: "us-west-2" }], data_paths: [])
    }.to raise_error(Bard::Backup::Error, /encryption_key for primary/)
  end

  it "refuses a data file tree that has no encryption key" do
    expect {
      Bard::Backup.encrypt_existing!([], data_paths: ["data"], project_name: "project", region: "us-west-2")
    }.to raise_error(Bard::Backup::Error, /encryption_key for bard-data\/project/)
  end
end
