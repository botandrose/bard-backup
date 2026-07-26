require "spec_helper"

RSpec.describe Bard::Backup::UploadDestination do
  describe "encryption key resolution" do
    before { hide_const("Rails") }

    it "uses the explicit key when given" do
      destination = described_class.new({ type: :upload, urls: ["https://example.com"], encryption_key: "explicit" })

      expect(destination.send(:encryption_key)).to eq("explicit")
    end

    it "is nil when no key is given" do
      destination = described_class.new({ type: :upload, urls: ["https://example.com"] })

      expect(destination.send(:encryption_key)).to be_nil
    end
  end
end
