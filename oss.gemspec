# -*- encoding: utf-8 -*-

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'oss/version'

Gem::Specification.new do |spec|
  spec.name          = 'aliyun-oss-sdk'
  spec.version       = Aliyun::OSS::VERSION
  spec.authors       = ['Tianlong Wu']
  spec.email         = ['tianlong.wtl@alibaba-inc.com']

  spec.summary       = 'Aliyun OSS Ruby SDK'
  spec.description   = 'Aliyun OSS Ruby SDK'
  spec.homepage      = 'https://gitlab.alibaba-inc.com/oss/ruby-sdk'

  spec.files         = `git ls-files`.split.reject { |f| f.match(%r{^(spec|examples)}) }
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'nokogiri'
  spec.add_dependency 'rest-client'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'webmock'
end
