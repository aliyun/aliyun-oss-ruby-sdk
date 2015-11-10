# -*- encoding: utf-8 -*-

require 'yaml'
require_relative '../lib/oss'

# 初始化OSS Bucket
Aliyun::OSS::Logging.set_log_level(Logger::DEBUG)
cred_file = "~/.oss.yml"
cred = YAML.load(File.read(File.expand_path(cred_file)))
oss = Aliyun::OSS::Client.new(
  'oss.aliyuncs.com', cred["id"], cred["key"]).get_bucket('t-hello-world')

oss.resumable_upload('resumable', '/tmp/x')
