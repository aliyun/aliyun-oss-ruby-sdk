# -*- encoding: utf-8 -*-

require 'yaml'
require_relative 'oss'

cred_file = "~/.oss.yml"
cred = YAML.load(File.read(File.expand_path(cred_file)))

oss = Aliyun::OSS::Client.new('oss.aliyuncs.com', cred["id"], cred["key"])

oss.list_bucket.each do |bucket|
  puts "Bucket: #{bucket.name}, location: #{bucket.location}"
end
