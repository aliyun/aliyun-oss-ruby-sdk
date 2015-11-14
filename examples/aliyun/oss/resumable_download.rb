# -*- encoding: utf-8 -*-

$:.unshift(File.expand_path("../../../../lib", __FILE__))
require 'yaml'
require 'aliyun/oss'

# 初始化OSS Bucket
Aliyun::OSS::Logging.set_log_level(Logger::DEBUG)
cred_file = "~/.oss.yml"
cred = YAML.load(File.read(File.expand_path(cred_file)))
bucket = Aliyun::OSS::Client.new(
  :endpoint => 'oss.aliyuncs.com',
  :access_key_id => cred["id"],
  :access_key_secret => cred["key"]).get_bucket('t-hello-world')

# 下载一个100M的文件
bucket.resumable_download('resumable', '/tmp/y')

# 测试方法：
# 1. ruby examples/resumable_download.rb
# 2. 过几秒后用Ctrl-C中断下载
# 3. ruby examples/resumable_download.rb恢复下载
