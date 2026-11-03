require "spec_helper"
require "open3"
require "rbconfig"

RSpec.describe "Bard::Backup::Railtie" do
  it "defines the bard:backup rake tasks without loading ActiveRecord" do
    script = <<~RUBY
      require "rails"
      require "bard/backup/railtie"
      class App < Rails::Application; end
      require "rake"
      App.load_tasks
      puts Rake::Task.task_defined?("bard:backup")
      puts defined?(ActiveRecord).inspect
    RUBY

    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-Ilib", "-e", script)

    expect(status).to be_success, stderr
    expect(stdout.lines.map(&:chomp)).to eq(["true", "nil"])
  end
end
