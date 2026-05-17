require "spec_helper"

RSpec.describe Bard::Backup::S3Destination do
  describe "#s3_tree" do
    context "when Rails credentials provide AWS keys for this destination's name" do
      let(:creds) do
        {
          path: "bucket/folder",
          access_key_id: "AKIA",
          secret_access_key: "SECRET",
          region: "us-east-1",
        }
      end

      before do
        stub_const(
          "Rails",
          double(application: double(credentials: double(bard_backup: creds.merge(name: "primary")))),
        )
      end

      it "merges Rails credentials by name so S3Tree gets path and AWS keys" do
        destination = described_class.new({ name: "primary", type: :s3 })

        expect(Bard::Backup::S3Tree).to receive(:new).with(
          endpoint: "https://s3.us-east-1.amazonaws.com",
          path: "bucket/folder",
          access_key_id: "AKIA",
          secret_access_key: "SECRET",
          region: "us-east-1",
        )

        destination.s3_tree
      end

      it "lets explicit config keys override Rails credentials" do
        destination = described_class.new({
          name: "primary",
          type: :s3,
          access_key_id: "OVERRIDE",
        })

        expect(Bard::Backup::S3Tree).to receive(:new).with(
          hash_including(access_key_id: "OVERRIDE", secret_access_key: "SECRET"),
        )

        destination.s3_tree
      end
    end

    context "when Rails credentials are absent" do
      before do
        hide_const("Rails")
      end

      it "passes through whatever the user provided" do
        destination = described_class.new({
          name: "primary",
          type: :s3,
          path: "explicit/path",
          access_key_id: "k",
          secret_access_key: "s",
          region: "us-west-2",
        })

        expect(Bard::Backup::S3Tree).to receive(:new).with(
          endpoint: "https://s3.us-west-2.amazonaws.com",
          path: "explicit/path",
          access_key_id: "k",
          secret_access_key: "s",
          region: "us-west-2",
        )

        destination.s3_tree
      end
    end
  end

  describe "#info" do
    it "exposes the resolved name/type/path/region after credential merge" do
      stub_const(
        "Rails",
        double(application: double(credentials: double(bard_backup: {
          name: "primary",
          path: "bucket/folder",
          region: "eu-west-1",
          access_key_id: "x",
          secret_access_key: "y",
        }))),
      )

      destination = described_class.new({ name: "primary", type: :s3 })

      expect(destination.info).to eq(
        name: "primary",
        type: :s3,
        path: "bucket/folder",
        region: "eu-west-1",
      )
    end
  end
end
