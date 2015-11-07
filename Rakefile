#!/usr/bin/env rake

require 'bundler'
require "bundler/gem_tasks"

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do
end

task :example do
  FileList['examples/*.rb'].each do |f|
    puts "==== Run example: #{f} ===="
    ruby f
  end
end

task :default => :spec
