require "bard/backup/deleter"

RSpec.describe Bard::Backup::Deleter do
  describe ".retain_until" do
    {
      "2026-11-18T13:00:04Z" => "2026-11-20T13:00:00Z", # hourly: 48 hours
      "2026-11-18T00:00:04Z" => "2026-12-18T00:00:00Z", # daily: 30 days
      "2026-11-16T00:00:04Z" => "2027-05-17T00:00:00Z", # Monday: 26 weeks
      "2026-12-01T00:00:04Z" => "2028-12-01T00:00:00Z", # first of the month: 24 months
      "2027-01-01T00:00:04Z" => "2052-01-01T00:00:00Z", # first of the year: 25 years
    }.each do |timestamp, until_time|
      it "keeps a #{timestamp} dump until #{until_time}" do
        expect(described_class.retain_until(Time.parse(timestamp))).to eq(Time.parse(until_time))
      end
    end

    it "is exactly when the hourly deleter first deletes the dump" do
      times = (0...24 * 400).map { |hours| Time.parse("2026-10-31T00:00:07Z") + hours * 3600 }
      times.sample(200, random: Random.new(1)).each do |time|
        file = "#{time.iso8601}.sql.gz"
        tree = double("S3Tree", list_objects: { file => "etag" })
        retain_until = described_class.retain_until(time)

        expect(described_class.new(tree, retain_until - 3600).files_to_delete).to be_empty, file
        expect(described_class.new(tree, retain_until).files_to_delete).to eq([file]), file
      end
    end
  end
end
