# -*- encoding: utf-8 -*-

require 'coveralls'
Coveralls.wear!

require 'webmock/rspec'
require 'aliyun/oss'
require 'aliyun/sts'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

end

Aliyun::Common::Logging::set_log_level(Logger::DEBUG)
