# frozen_string_literal: true

require_relative "lib/bard/backup/version"

Gem::Specification.new do |spec|
  spec.name = "bard-backup"
  spec.version = Bard::Backup::VERSION
  spec.authors = ["Micah Geisel"]
  spec.email = ["micah@botandrose.com"]

  spec.summary = "Provides automated db backups for bard projects"
  spec.homepage = "https://github.com/botandrose/bard-backup"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "backhoe"
  spec.add_dependency "aws-sdk-s3", "~>1.0"
  spec.add_dependency "rexml"
  spec.add_dependency "activesupport"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
