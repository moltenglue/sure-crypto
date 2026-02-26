ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

# In CI test environment, skip encrypted credentials loading to avoid decryption errors.
# The app uses environment variables for secrets in CI instead.
ENV["SKIP_CREDENTIALS"] = "true" if ENV["CI"] == "true" && ENV["RAILS_ENV"] == "test"
