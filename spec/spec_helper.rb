# frozen_string_literal: true

require 'redis_single_file'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # set rspec expect syntax
  config.expect_with(:rspec) { _1.syntax = :expect }

  # load heler files from support directory
  Dir[File.join(__dir__, 'support/**/*.rb')].each { require _1 }
end
