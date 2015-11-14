# -*- encoding: utf-8 -*-

require 'simplecov'
SimpleCov.start

require 'webmock/rspec'
require 'aliyun/oss'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

end

Aliyun::OSS::Logging::set_log_level(Logger::DEBUG)
