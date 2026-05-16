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

# Inserts ENV["TEST_NAMESPACE"] after the bucket segment so concurrent CI runs
# don't stomp on each other's S3 state. The bard-data bucket is opted out because
# its STS role only grants access to specific top-level prefixes.
def namespaced(path)
  ns = ENV["TEST_NAMESPACE"]
  return path if ns.nil? || ns.empty?
  bucket, *rest = path.split("/")
  return path if bucket == "bard-data"
  [bucket, ns, *rest].join("/")
end

def namespaced_project(project_name)
  ns = ENV["TEST_NAMESPACE"]
  return project_name if ns.nil? || ns.empty?
  "#{ns}/#{project_name}"
end
