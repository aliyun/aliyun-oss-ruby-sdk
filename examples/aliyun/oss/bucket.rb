# -*- encoding: utf-8 -*-

$:.unshift(File.expand_path("../../../../lib", __FILE__))
require 'yaml'
require 'aliyun/oss'

# 初始化OSS client
Aliyun::OSS::Logging.set_log_level(Logger::DEBUG)
cred_file = "~/.oss.yml"
cred = YAML.load(File.read(File.expand_path(cred_file)))
client = Aliyun::OSS::Client.new('oss.aliyuncs.com', cred["id"], cred["key"])
bucket = client.get_bucket('t-hello-world')

# 列出当前所有的bucket
buckets = client.list_buckets
buckets.each{ |b| puts "Bucket: #{b.name}"}

# 创建bucket
bucket.create!(:location => 'oss-cn-hangzhou')
client.get_bucket('t-foo-bar').create!

# 向bucket中添加4个空的object:
# foo/obj1, foo/bar/obj1, foo/bar/obj2, foo/xxx/obj1
bucket.put_object('foo/obj1') {}
bucket.put_object('foo/bar/obj1') {}
bucket.put_object('foo/bar/obj2') {}
bucket.put_object('foo/xxx/obj1') {}
bucket.put_object('中国の') {}

# list bucket下所有objects
objects = bucket.list_objects

puts "All objects:"
objects.each do |o|
  puts "Object: #{o.key}, type: #{o.type}, size: #{o.size}"
end
puts

# list bucket下所有前缀为foo/bar/的object
objects = bucket.list_objects(:prefix => 'foo/bar/')

puts "All objects begin with 'foo/bar/':"
objects.each do |o|
  puts "Object: #{o.key}, type: #{o.type}, size: #{o.size}"
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

objects = bucket.list_objects(:prefix => 'foo/', :delimiter => '/')

puts "All objects begin with 'foo/':"
objects.each do |o|
  if o.is_a?(Aliyun::OSS::Object)
    puts "Object: #{o.key}, type: #{o.type}, size: #{o.size}"
  else
    puts "Common prefix: #{o}"
  end
end
