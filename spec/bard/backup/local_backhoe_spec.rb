RSpec.describe Bard::Backup::LocalBackhoe do
  let(:dumper) { spy }
  let(:s3_tree) { spy }
  let(:now) { Time.parse("2020-04-20T12:30:00Z") }

  subject do
    described_class.call(s3_tree, now)
  end

  before do
    stub_const "Backhoe", dumper
    allow(Bard::Config).to receive(:current).and_return(double(project_name: "mimic"))
  end

  it "works" do
    subject
    expect(dumper).to have_received(:dump) do |path|
      expect(File.basename(path)).to eq("2020-04-20T12:30:00Z.sql.gz")
      expect(s3_tree).to have_received(:mv).with(path)
    end
  end

  it "dumps into its own directory, so a concurrent backup of the same second can't take its file" do
    paths = []
    allow(dumper).to receive(:dump) { |path| paths << path }
    2.times { described_class.call(s3_tree, now) }

    expect(paths.uniq.size).to eq(2)
    expect(paths.map { |path| File.basename(File.dirname(path)) }).to all(start_with("mimic-backup-"))
  end
end
