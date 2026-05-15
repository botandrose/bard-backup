require "spec_helper"
require "bard/backup/rails_credentials"

RSpec.describe Bard::Backup::RailsCredentials do
  describe ".find" do
    context "without Rails" do
      it "returns an empty hash" do
        expect(described_class.find).to eq({})
        expect(described_class.find(name: "anything")).to eq({})
      end
    end

    context "with Rails but no bard_backup credentials" do
      before do
        stub_const("Rails", double(application: double(credentials: double(bard_backup: nil))))
      end

      it "returns an empty hash" do
        expect(described_class.find).to eq({})
        expect(described_class.find(name: "primary")).to eq({})
      end
    end

    context "when credentials is a single hash" do
      let(:creds) { { access_key_id: "a", secret_access_key: "b", region: "us-west-2" } }

      before do
        stub_const("Rails", double(application: double(credentials: double(bard_backup: creds))))
      end

      it "returns the hash when called without a name" do
        expect(described_class.find).to eq(creds)
      end

      it "returns the hash when name is nil" do
        expect(described_class.find(name: nil)).to eq(creds)
      end

      it "returns empty when name does not match" do
        expect(described_class.find(name: "other")).to eq({})
      end
    end

    context "when credentials is an array" do
      let(:primary) { { name: "primary", access_key_id: "a", secret_access_key: "b" } }
      let(:secondary) { { name: "secondary", access_key_id: "c", secret_access_key: "d" } }

      before do
        stub_const("Rails", double(application: double(credentials: double(bard_backup: [primary, secondary]))))
      end

      it "returns the entry matching the given name" do
        expect(described_class.find(name: "secondary")).to eq(secondary)
      end

      it "returns the first entry when no name is provided" do
        expect(described_class.find).to eq(primary)
      end

      it "returns empty when name does not match any entry" do
        expect(described_class.find(name: "missing")).to eq({})
      end
    end
  end
end
