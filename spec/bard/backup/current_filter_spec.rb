require "bard/backup/deleter"

RSpec.describe Bard::Backup::Deleter::CurrentFilter do
  subject do
    described_class.new(time)
  end

  let(:time) { Time.parse("2020-06-19T06:01:12Z") }

  it "should cover variation in seconds" do
    expect(subject).to be_cover("2020-06-19T06:01:04Z.sql.gz")
  end

  it "should cover variation in minutes" do
    expect(subject).to be_cover("2020-06-19T06:02:12Z.sql.gz")
  end

  it "should NOT cover variation in hours" do
    expect(subject).to be_cover("2020-06-19T06:01:12Z.sql.gz")
  end

  it "should NOT cover variation in days" do
    expect(subject).to_not be_cover("2020-06-20T06:01:12Z.sql.gz")
  end

  it "should NOT cover variation in months" do
    expect(subject).to_not be_cover("2020-07-19T06:01:12Z.sql.gz")
  end

  it "should NOT cover variation in years" do
    expect(subject).to_not be_cover("2021-06-19T06:01:12Z.sql.gz")
  end
end

