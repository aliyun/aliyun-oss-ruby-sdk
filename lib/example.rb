# -*- encoding: utf-8 -*-

require 'yaml'
require_relative 'oss'

cred_file = "~/.oss.yml"
cred = YAML.load(File.read(File.expand_path(cred_file)))

oss = Aliyun::OSS::Client.new('oss.aliyuncs.com', cred["id"], cred["key"])

puts oss.list_bucket
