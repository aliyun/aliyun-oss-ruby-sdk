# -*- encoding: utf-8 -*-

$LOAD_PATH.unshift(File.expand_path("../../../../lib", __FILE__))
require 'yaml'
require 'aliyun/oss'

# 初始化OSS Bucket
Aliyun::OSS::Logging.set_log_level(Logger::DEBUG)
conf_file = '~/.oss.yml'
conf = YAML.load(File.read(File.expand_path(conf_file)))
bucket = Aliyun::OSS::Client.new(
  :endpoint => 'oss.aliyuncs.com',
  :access_key_id => conf['id'],
  :access_key_secret => conf['key']).get_bucket(conf['bucket'])

# 下载一个100M的文件
start = Time.now
puts "Start download..."
bucket.resumable_download('resumable', '/tmp/y', :cpt_file => '/tmp/y.cpt')
puts "Download complete. Cost: #{Time.now - start} seconds."

# 测试方法：
# 1. ruby examples/resumable_download.rb
# 2. 过几秒后用Ctrl-C中断下载
# 3. ruby examples/resumable_download.rb恢复下载
