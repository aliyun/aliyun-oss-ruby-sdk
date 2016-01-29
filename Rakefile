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

Rake::TestTask.new do |t|
  t.pattern = "tests/**/test_*.rb"
end

task :default => :spec

task :smart_test do
  Rake::Task[:spec].invoke
  Rake::Task[:test].invoke if ENV.keys.include?('RUBY_SDK_OSS_KEY')
end
