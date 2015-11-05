# -*- encoding: utf-8 -*-

require 'yaml'
require_relative '../lib/oss'

##
# Multipart相关的操作主要有：
# - begin_multipart 开启一个multipart上传的事务，返回事务id，后续的
# multipart操作都需要用到这个id
# - upload_part 在一个multipart上传事务中上传一个part，类似于
# put_object，不同之处在于upload_part完成之后object并没有创建成功，因
# 为multipart的object包含多个part，所以要在commit_multipart之后object
# 才是可见的
# - copy_part 类似于upload_part，不同的是part的内容由一个已经存在的
# object提供
# - commit_multipart 提交一个multipart事务，提交的请求中包含这个事务的
# 所有part，服务器端逐一确认这些part都上传成功。如果有任意一个part没有
# 上传成功，commit_multipart都会失败。如果commit_multipart返
# 回成功，则object已经创建好。
# - abort_multipart 中止一个multipart事务，之前已经上传成功的part会被
# 删除。正在上传的part可能会成功，这时只需在所有的上传都结束后再次中止
# 即可。
# - list_multipart_transactions 获取正在进行的multipart事务，可以指定
# prefix, marker等来过滤要返回的事务列表
# - list_parts 获取一个multipart事务的part列表，可以指定prefix, marker
# 等来过滤要返回的part列表

# 初始化OSS client
Aliyun::OSS::Logging.set_log_level(Logger::DEBUG)
cred_file = "~/.oss.yml"
cred = YAML.load(File.read(File.expand_path(cred_file)))
oss = Aliyun::OSS::Client.new('oss.aliyuncs.com', cred["id"], cred["key"])

# 创建一个bucket，默认的location为oss-cn-hangzhou
oss.create_bucket('t-hello-world')

# 开启一个multipart事务
txn_id = oss.begin_multipart('t-hello-world', 'multipart.file')
puts "开启一个multipart事务：#{txn_id}"

# 上传5个part
parts = []
(1..5).each do |i|
  p = oss.upload_part('t-hello-world', 'multipart.file', txn_id, i) do |content|
    # 非最后一个part的大小最小是100KB
    content.write_and_finish 'multipart\n' * (11 * 1024)
  end
  parts << p
  puts "成功上传一个part: #{p.number}"
end

# 提交multipart事务
oss.commit_multipart('t-hello-world', 'multipart.file', txn_id, parts)

# 查看文件
objects, _ = oss.list_object('t-hello-world', :prefix => 'multipart')

puts "All objects:"
objects.each do |o|
  puts "object: #{o.key}, type: #{o.type}, size: #{o.size}"
end
puts
