# -*- encoding: utf-8 -*-

require 'yaml'
require_relative '../lib/oss'

##
# Object相关的操作主要有：
# - PutObject 向bucket中创建一个object，object的内容可以从文件中读取，
#      也可以流式读取。如果object已存在，则会覆盖。
# - AppendObject 向bucket中的一个object追加内容，内容可以从文件中读取，
#      也可以流式读取。如果object不存在，则会创建一个appendable object
# - CopyObject 拷贝bucket中的一个object，生成一个新的object。可以通过
#      这种方式来修改object的meta
# - GetObject 下载bucket中的一个object，object的内容可以下载到一个文件，
#      也可以流式处理
# - DeleteObject 删除bucket中的一个object

# 初始化OSS client
Aliyun::OSS::Logging.set_log_level(Logger::DEBUG)
cred_file = "~/.oss.yml"
cred = YAML.load(File.read(File.expand_path(cred_file)))
oss = Aliyun::OSS::Client.new('oss.aliyuncs.com', cred["id"], cred["key"])

# 创建一个bucket
oss.create_bucket('t-hello-world')

# 在bucket中创建一个object：上传一个文件
File.open('/tmp/x', 'w') do |f|
  f.puts 'hello, file.'
end

oss.put_object_from_file('t-hello-world', 'obj.file', '/tmp/x')

# 在bucket中创建一个object：流式读取内容
# 更多流式处理表参考：examples/streaming.rb
oss.put_object('t-hello-world', 'obj.stream') do |content|
  content.write_and_finish 'hello, stream.'
end

# 创建一个appendable object，从文件中读取
File.open('/tmp/x', 'w') do |f|
  f.write 'hello, appendable file.'
end

oss.delete_object('t-hello-world', 'app-obj')
oss.append_object_from_file('t-hello-world', 'app-obj', 0, '/tmp/x')

# 向appendable object中追加内容
# position必须是当前object的长度，否则追加会失败
position = 'hello, appendable file.'.size
oss.append_object('t-hello-world', 'app-obj', position) do |content|
  content.write_and_finish 'hello, append from stream.'
end

# 使用错误的position进行追加会失败
begin
  oss.append_object('t-hello-world', 'app-obj', position - 1) {}
rescue => e
  puts "Append failed: #{e.message}"
end

# 向一个normal object中追加内容会失败
begin
  oss.append_object('t-hello-world', 'obj.file', position) {}
rescue => e
  puts "Append failed: #{e.message}"
end

# 拷贝一个object
oss.copy_object('t-hello-world', 'obj.file', 'obj.file.copy')

# 拷贝一个appendable object会失败
begin
  oss.copy_object('t-hello-world', 'app-obj', 'app-obj.copy')
rescue => e
  puts "Copy object failed: #{e.message}"
end

# 下载一个object：下载到本地文件中
oss.get_object_to_file('t-hello-world', 'obj.file', '/tmp/obj.file')

# 下载一个object：流式处理
# 更多流式处理的细节请参考：examples/streaming.rb
total_size = 0
oss.get_object('t-hello-world', 'obj.file') do |chunk|
  total_size += chunk.size
end
puts "Total size: #{total_size}"

# 删除一个object
oss.delete_object('t-hello-world', 'obj.file')

# 删除一个不存在的object返回OK
# 这意味着delete_object是幂等的，在删除失败的时候可以不断重试，直到成
# 功，成功意味着object已经不存在
oss.delete_object('t-hello-world', 'non-existent-object')
