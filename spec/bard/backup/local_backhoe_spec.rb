RSpec.describe Bard::Backup::LocalBackhoe do
  let(:dumper) { spy }
  let(:s3_dir) { spy }
  let(:now) { Time.parse("2020-04-20T12:30:00Z") }

  subject do
    described_class.call(s3_dir, now)
  end

  before { stub_const "Backhoe", dumper }

  it "works" do
    subject.call
    expect(dumper).to have_received(:dump).with("/tmp/2020-04-20T12:30:00Z.sql.gz")
    expect(s3_dir).to have_received(:mv).with("/tmp/2020-04-20T12:30:00Z.sql.gz")
  end
end

