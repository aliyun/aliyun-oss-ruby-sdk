# -*- encoding: utf-8 -*-

require 'yaml'
require_relative '../lib/oss'

##
# Bucket相关的操作主要有：
# - ListObjects 获取bucket中的objects，当bucket中的object数量较多时，
#      可以通过prefix, delimiter等参数过滤出特定的object
# - CreateBucket 创建bucket，可以通过参数设置bucket的acl, location等属
#      性，也可以将bucket也用户的website关联
# - DeleteBucket 删除bucket，要求所删除的bucket中不含object，否则会删
#      除失败

# 初始化OSS client
Aliyun::OSS::Logging.set_log_level(Logger::DEBUG)
cred_file = "~/.oss.yml"
cred = YAML.load(File.read(File.expand_path(cred_file)))
oss = Aliyun::OSS::Client.new('oss.aliyuncs.com', cred["id"], cred["key"])

# 创建一个bucket，默认的location为oss-cn-hangzhou
oss.create_bucket('t-hello-world')

# 创建一个location为oss-cn-hangzhou的bucket
oss.create_bucket('t-hello-hz', :location => 'oss-cn-hangzhou')

# 向t-hello-hz中添加一个object
oss.put_object('t-hello-hz', 'file') do |content|
  content.write_and_finish 'hello, world'
end

# 删除一个bucket => 失败，因为bucket不为空
begin
  oss.delete_bucket('t-hello-hz')
rescue => e
  puts "Delete bucket failed: #{e.message}"
end

# 删除这个bucket中的object，之后再删除这个bucket
oss.delete_object('t-hello-hz', 'file')

# 删除成功
oss.delete_bucket('t-hello-hz')

# 向bucket: t-hello-world中添加4个object:
# foo/obj1, foo/bar/obj1, foo/bar/obj2, foo/xxx/obj1
oss.put_object('t-hello-world', 'foo/obj1') {}
oss.put_object('t-hello-world', 'foo/bar/obj1') {}
oss.put_object('t-hello-world', 'foo/bar/obj2') {}
oss.put_object('t-hello-world', 'foo/xxx/obj1') {}
oss.put_object('t-hello-world', '中国の') {}

# list所有object
objects, more = oss.list_object('t-hello-world')

puts "All objects:"
objects.each do |o|
  puts "object: #{o.key}, type: #{o.type}, size: #{o.size}"
end
puts

# list所有前缀为foo/bar/的object
objects, more = oss.list_object('t-hello-world', :prefix => 'foo/bar/')

puts "All objects begin with 'foo/bar':"
objects.each do |o|
  puts "object: #{o.key}, type: #{o.type}, size: #{o.size}"
end
puts

# list所有前缀为foo/bar的object，限制一次最多返回1个
objects, more = oss.list_object(
           't-hello-world', :prefix => 'foo/bar/', :limit => 1)

puts "First 1 objects begin with 'foo/bar':"
objects.each do |o|
  puts "object: #{o.key}, type: #{o.type}, size: #{o.size}"
end
# more中包含了下一个object的marker
puts "Next marker: #{more[:next_marker]}"

# 从next marker开始list object，获取剩余的object
objects, more = oss.list_object(
           't-hello-world',
           :prefix => 'foo/bar/', :marker => more[:next_marker])
puts "Remaining objects begin with 'foo/bar':"
objects.each do |o|
  puts "object: #{o.key}, type: #{o.type}, size: #{o.size}"
end
puts

# 获取object的common prefix，common prefix是指bucket下所有object（也可
# 以指定特定的前缀）的公共前缀，这在object数量巨多的时候很有用，例如有
# 如下的object：
#     /foo/bar/obj1
#     /foo/bar/obj2
#     ...
#     /foo/bar/obj9999999
#     /foo/xx/
# 指定foo/为prefix，/为delimiter，则返回的common prefix为
# /foo/bar/, /foo/xxx/
# 这可以表示/foo/目录下的子目录。如果没有common prefix，你可能要遍历所
# 有的object来找公共的前缀

objects, more = oss.list_object(
           't-hello-world', :prefix => 'foo/', :delimiter => '/')

puts "All objects begin with 'foo/':"
objects.each do |o|
  puts "object: #{o.key}, type: #{o.type}, size: #{o.size}"
end
puts "Common prefixes with prefix = 'foo/' and delimiter = '/':"
(more[:common_prefixes] || []).each do |p|
  puts "common prefix: #{p}"
end
puts
