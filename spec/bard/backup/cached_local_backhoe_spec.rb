require "rbconfig"

RSpec.describe Bard::Backup::CachedLocalBackhoe do
  let(:dumped) { [] }
  let(:uploads) { [] }

  let(:s3_tree) do
    double(:s3_tree).tap do |tree|
      allow(tree).to receive(:put_file) { |path, key| uploads << [key, File.binread(path)] }
      allow(tree).to receive(:mv) do |path|
        uploads << [File.basename(path), File.binread(path)]
        FileUtils.rm(path)
      end
    end
  end

  before do
    backhoe = double(:backhoe)
    allow(backhoe).to receive(:dump) do |path|
      dumped << path
      File.write(path, "DUMP #{dumped.size}")
    end
    stub_const "Backhoe", backhoe
    allow(Bard::Config).to receive(:current).and_return(double(project_name: "mimic"))
  end

  # The cache is process-wide, so each example backs up at its own second.
  def at(second) = Time.utc(2026, 11, 15, 19, 0, second)

  it "dumps once and shares the dump across every destination in a run" do
    2.times { described_class.call(s3_tree, at(1)) }

    expect(dumped.size).to eq(1)
    expect(uploads).to eq([["2026-11-15T19:00:01Z.sql.gz", "DUMP 1"]] * 2)
  end

  it "dumps into a directory named for the project" do
    described_class.call(s3_tree, at(7))

    expect(File.basename(File.dirname(dumped.first))).to start_with("mimic-backup-")
  end

  it "redumps when the cached dump has gone missing" do
    described_class.call(s3_tree, at(2))
    FileUtils.rm(dumped.last)

    expect { described_class.call(s3_tree, at(2)) }.not_to raise_error
    expect(dumped.size).to eq(2)
    expect(uploads.last).to eq(["2026-11-15T19:00:02Z.sql.gz", "DUMP 2"])
  end

  it "redumps for a later run instead of re-uploading the earlier run's dump" do
    described_class.call(s3_tree, at(3))
    described_class.call(s3_tree, at(4))

    expect(dumped.size).to eq(2)
    expect(uploads.last).to eq(["2026-11-15T19:00:04Z.sql.gz", "DUMP 2"])
    expect(File.exist?(dumped.first)).to be(false)
  end

  it "keeps its dump when LocalBackhoe backs up the same second" do
    described_class.call(s3_tree, at(5))
    Bard::Backup::LocalBackhoe.call(s3_tree, at(5))

    expect(dumped.uniq.size).to eq(2)
    expect(File.exist?(dumped.first)).to be(true)
  end

  it "keeps its dump when another process backs up the same second and exits" do
    described_class.call(s3_tree, at(6))

    other_process = <<~RUBY
      require "bard/backup"
      def Backhoe.dump(path)
        File.write(path, "OTHER")
      end
      tree = Object.new
      def tree.put_file(path, key) = File.binread(path)
      Bard::Backup::CachedLocalBackhoe.call(tree, Time.iso8601(ARGV.fetch(0)))
    RUBY
    lib = File.expand_path("../../../lib", __dir__)
    system(RbConfig.ruby, "-I", lib, "-e", other_process, at(6).iso8601, exception: true)

    expect(File.binread(dumped.first)).to eq("DUMP 1")
  end
end
