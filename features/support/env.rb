require "json"
require "time"

require "rspec/expectations"
require "rspec/mocks"

require "bard/backup"
require_relative "../../spec/support/fake_backhoe"

World(RSpec::Matchers)
World(RSpec::Mocks::ExampleMethods)

Before do
  RSpec::Mocks.setup
end

After do
  RSpec::Mocks.verify
  RSpec::Mocks.teardown
end
