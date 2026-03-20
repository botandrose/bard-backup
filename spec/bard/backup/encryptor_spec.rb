require "bard/backup/encryptor"

RSpec.describe Bard::Backup::Encryptor do
  let(:key) { "test-master-key-0123456789abcdef" }
  let(:encryptor) { described_class.new(key) }

  it "round-trips: encrypt then decrypt returns original" do
    plaintext = "hello world"
    expect(encryptor.decrypt(encryptor.encrypt(plaintext))).to eq(plaintext)
  end

  it "is deterministic: same plaintext + same key = same ciphertext" do
    plaintext = "deterministic test"
    expect(encryptor.encrypt(plaintext)).to eq(encryptor.encrypt(plaintext))
  end

  it "produces different ciphertext for different plaintext" do
    expect(encryptor.encrypt("aaa")).not_to eq(encryptor.encrypt("bbb"))
  end

  it "raises on wrong key" do
    ciphertext = encryptor.encrypt("secret")
    wrong = described_class.new("wrong-key-0123456789abcdefgh")
    expect { wrong.decrypt(ciphertext) }.to raise_error(OpenSSL::Cipher::CipherError)
  end

  it "round-trips binary data" do
    binary = (0..255).map(&:chr).join.b
    expect(encryptor.decrypt(encryptor.encrypt(binary))).to eq(binary)
  end

  it "round-trips empty string" do
    expect(encryptor.decrypt(encryptor.encrypt(""))).to eq("")
  end
end
