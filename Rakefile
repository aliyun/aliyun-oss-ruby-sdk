#!/usr/bin/env rake

require 'bundler'
require "bundler/gem_tasks"
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do
  Bundler.setup(:default, :test)
end

task :example do
  FileList['examples/**/*.rb'].each do |f|
    puts "==== Run example: #{f} ===="
    ruby f
  end
end

require 'rake/testtask'

begin
  require 'rake/extensiontask'
rescue LoadError
  abort <<-error
  rake-compile is missing; Rugged depends on rake-compiler to build the C wrapping code.

  Install it by running `gem i rake-compiler`
error
end

gemspec = Gem::Specification::load(File.expand_path('../aliyun-sdk.gemspec', __FILE__))

Gem::PackageTask.new(gemspec) do |pkg|
end

Rake::ExtensionTask.new('crcx', gemspec) do |ext|
  ext.lib_dir = 'lib/aliyun'
end

Rake::TestTask.new do |t|
  t.pattern = "tests/**/test_*.rb"
end

task :default => [:compile, :spec]

task :smart_test do
  
  # run spec test
  Rake::Task[:spec].invoke
  
  if ENV.keys.include?('RUBY_SDK_OSS_KEY')
    begin
      env_crc_enable = ENV['RUBY_SDK_OSS_CRC_ENABLE']

      # run test without crc
      ENV['RUBY_SDK_OSS_CRC_ENABLE'] = nil if ENV['RUBY_SDK_OSS_CRC_ENABLE']
      Rake::Task[:test].invoke 

      # run test with crc
      ENV['RUBY_SDK_OSS_CRC_ENABLE'] = 'true'
      Rake::Task[:test].invoke
    ensure
      ENV['RUBY_SDK_OSS_CRC_ENABLE'] = env_crc_enable
    end
  end
end

Rake::Task[:smart_test].prerequisites << :compile
