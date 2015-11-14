# -*- encoding: utf-8 -*-

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aliyun/oss/version'

Gem::Specification.new do |spec|
  spec.name          = 'aliyun-sdk'
  spec.version       = Aliyun::OSS::VERSION
  spec.authors       = ['Tianlong Wu']
  spec.email         = ['tianlong.wtl@alibaba-inc.com']

  spec.summary       = 'Aliyun OSS SDK for Ruby'
  spec.description   = 'A Ruby program to facilitate accessing Aliyun Object Storage Service'
  spec.homepage      = 'https://gitlab.alibaba-inc.com/oss/ruby-sdk'

  spec.files         = Dir.glob("lib/**/*.rb")
  spec.test_files    = Dir.glob("spec/**/*_spec.rb")
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.license       = 'MIT'

  spec.add_dependency 'nokogiri'
  spec.add_dependency 'rest-client'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'webmock'

  spec.required_ruby_version = '>= 1.9.3'
end
