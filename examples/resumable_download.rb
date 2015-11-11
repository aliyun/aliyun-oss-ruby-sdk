# -*- encoding: utf-8 -*-

require 'yaml'
require_relative '../lib/oss'

# 初始化OSS Bucket
Aliyun::OSS::Logging.set_log_level(Logger::DEBUG)
cred_file = "~/.oss.yml"
cred = YAML.load(File.read(File.expand_path(cred_file)))
oss = Aliyun::OSS::Client.new(
  'oss.aliyuncs.com', cred["id"], cred["key"]).get_bucket('t-hello-world')

# 下载一个100M的文件
oss.resumable_download('resumable', '/tmp/y')

# 测试方法：
# 1. ruby examples/resumable_download.rb
# 2. 过几秒后用Ctrl-C中断下载
# 3. ruby examples/resumable_download.rb恢复下载
