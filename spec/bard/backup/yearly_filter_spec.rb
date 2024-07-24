require "bard/backup/deleter"

RSpec.describe Bard::Backup::Deleter::YearlyFilter do
  subject do
    described_class.new(time, 3)
  end

  let(:time) { Time.parse("2020-06-19T06:01:12Z") }

  it "should cover variation in seconds" do
    expect(subject).to be_cover("2020-01-01T00:01:04Z.sql.gz")
  end

  it "should cover variation in minutes" do
    expect(subject).to be_cover("2020-01-01T00:02:12Z.sql.gz")
  end

  it "should NOT cover variation in hours" do
    expect(subject).to_not be_cover("2020-01-01T01:01:12Z.sql.gz")
  end

  it "should NOT cover variation in days" do
    expect(subject).to_not be_cover("2020-01-02T00:01:12Z.sql.gz")
  end

  it "should NOT cover variation in months" do
    expect(subject).to_not be_cover("2019-12-01T00:01:12Z.sql.gz")
  end

  it "should cover variation in years back to configured limit" do
    expect(subject).to_not be_cover("2021-01-01T00:01:12Z.sql.gz")
    expect(subject).to be_cover("2020-01-01T00:01:12Z.sql.gz")
    expect(subject).to be_cover("2019-01-01T00:01:12Z.sql.gz")
    expect(subject).to be_cover("2018-01-01T00:01:12Z.sql.gz")
    expect(subject).to_not be_cover("2017-01-01T00:01:12Z.sql.gz")
  end
end

