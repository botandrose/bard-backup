RSpec.describe Bard::Backup::Controller do
  let(:dumper) { spy }
  let(:s3_dir) { spy }
  let(:filename) { "2020-04-20T12:30:00Z.sql.gz" }

  subject do
    described_class.new(dumper, s3_dir, filename)
  end

  it "works" do
    subject.call
    expect(dumper).to have_received(:dump).with("/tmp/#{filename}")
    expect(s3_dir).to have_received(:put).with("/tmp/#{filename}")
  end
end

