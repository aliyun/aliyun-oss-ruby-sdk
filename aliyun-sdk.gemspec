# -*- encoding: utf-8 -*-

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aliyun/version'

Gem::Specification.new do |spec|
  spec.name          = 'aliyun-sdk'
  spec.version       = Aliyun::VERSION
  spec.authors       = ['Tianlong Wu']
  spec.email         = ['rockuw.@gmail.com']

  spec.summary       = 'Aliyun OSS SDK for Ruby'
  spec.description   = 'A Ruby program to facilitate accessing Aliyun Object Storage Service'
  spec.homepage      = 'https://github.com/aliyun/aliyun-oss-ruby-sdk'

  spec.files         = Dir.glob("lib/**/*.rb") + Dir.glob("examples/**/*.rb") + Dir.glob("ext/**/*.{rb,c,h}")
  spec.test_files    = Dir.glob("spec/**/*_spec.rb") + Dir.glob("tests/**/*.rb")
  spec.extra_rdoc_files = ['README.md', 'CHANGELOG.md']
  spec.bindir        = 'lib/aliyun'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.license       = 'MIT'
  spec.extensions    = ['ext/crcx/extconf.rb']


  spec.add_dependency 'nokogiri', '~> 1.6'
  spec.add_dependency 'rest-client', '~> 2.0.2'

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake', '~> 10.4'
  spec.add_development_dependency 'rake-compiler', '~> 0.9.0'
  spec.add_development_dependency 'rspec', '~> 3.3'
  spec.add_development_dependency 'webmock', '~> 3.0'
  spec.add_development_dependency 'simplecov', '~> 0.10.0'
  spec.add_development_dependency 'minitest', '~> 5.8'

  spec.required_ruby_version = '>= 1.9.3'
end
