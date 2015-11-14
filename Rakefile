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

task :default => :spec
