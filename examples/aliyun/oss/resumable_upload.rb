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

# 生成一个100M的文件
File.open('/tmp/x', 'w') do |f|
  (1..1024*1024).each{ |i| f.puts i.to_s.rjust(99, '0') }
end

# 上传一个100M的文件
start = Time.now
puts "Start upload..."
bucket.resumable_upload('resumable', '/tmp/x', :cpt_file => '/tmp/x.cpt')
puts "Upload complete. Cost: #{Time.now - start} seconds."

# 测试方法：
# 1. ruby examples/resumable_upload.rb
# 2. 过几秒后用Ctrl-C中断上传
# 3. ruby examples/resumable_upload.rb恢复上传
