require "spec_helper"

RSpec.describe Bard::Backup::UploadDestination do
  describe "encryption key resolution" do
    before { hide_const("Rails") }

    it "uses the explicit key when given" do
      destination = described_class.new({ type: :upload, urls: ["https://example.com"], encryption_key: "explicit" })

      expect(destination.send(:encryption_key)).to eq("explicit")
    end

    it "falls back to the configured encryption key" do
      allow(Bard::Config).to receive(:current).and_return(double(backup: double(encryption_key: "cfg-key")))
      destination = described_class.new({ type: :upload, urls: ["https://example.com"] })

      expect(destination.send(:encryption_key)).to eq("cfg-key")
    end

    it "is nil when neither is set" do
      allow(Bard::Config).to receive(:current).and_return(double(backup: double(encryption_key: nil)))
      destination = described_class.new({ type: :upload, urls: ["https://example.com"] })

      expect(destination.send(:encryption_key)).to be_nil
    end
  end
end
