# -*- encoding: utf-8 -*-

$LOAD_PATH.unshift(File.expand_path("../../../../lib", __FILE__))
require 'yaml'
require 'aliyun/oss'

# 初始化OSS client
Aliyun::OSS::Logging.set_log_level(Logger::DEBUG)
conf_file = '~/.oss.yml'
conf = YAML.load(File.read(File.expand_path(conf_file)))
bucket = Aliyun::OSS::Client.new(
  :endpoint => conf['endpoint'],
  :cname => conf['cname'],
  :access_key_id => conf['id'],
  :access_key_secret => conf['key']).get_bucket(conf['bucket'])

# 上传一个object
# 流式上传请参考：examples/streaming.rb
bucket.put_object('files/hello') do |content|
  content << 'hello world.'
end

# 上传一个文件
# 断点续传请参考：examples/resumable_upload.rb
File.open('/tmp/x', 'w'){ |f| f.write("hello world\n") }
bucket.put_object('files/world', :file => '/tmp/x')

# 创建一个Appendable object
size = bucket.get_object_meta('files/appendable').size rescue 0
bucket.append_object('files/appendable', size) do |content|
  content << 'hello appendable.'
end

# 向files/appendable中追加内容
# 首先要获取object当前的长度
size = bucket.get_object_meta('files/appendable').size
bucket.append_object('files/appendable', size) do |content|
  content << 'again appendable.'
end

# 使用错误的position进行追加会失败
begin
  bucket.append_object('files/appendable', 0) do |content|
    content << 'again appendable.'
  end
rescue => e
  puts "Append failed: #{e.message}"
end

# 向一个normal object中追加内容会失败
begin
  bucket.append_object('files/hello', 0) do |content|
    content << 'hello appendable.'
  end
rescue => e
  puts "Append object failed: #{e.message}"
end

# 拷贝一个object
bucket.copy_object('files/hello', 'files/copy')

# 拷贝一个appendable object会失败
begin
  bucket.copy_object('files/appendable', 'files/copy')
rescue => e
  puts "Copy object failed: #{e.message}"
end

# 下载一个object：流式处理
# 流式下载请参考：examples/streaming.rb
total_size = 0
bucket.get_object('files/hello') do |chunk|
  total_size += chunk.size
end
puts "Total size: #{total_size}"

# 下载一个object：下载到文件中
bucket.get_object('files/hello', :file => '/tmp/hello')

# 删除一个object
bucket.delete_object('files/world')

# 查看以files/为前缀的所有object
bucket.list_objects(:prefix => 'files/').each do |o|
  puts "Object: #{o.key}, type: #{o.type}, size: #{o.size}"
end

# 删除一个不存在的object返回OK
# 这意味着delete_object是幂等的，在删除失败的时候可以不断重试，直到成
# 功，成功意味着object已经不存在
bucket.delete_object('non-existent-object')

# 设置Object metas
bucket.put_object(
  'files/hello',
  :metas => {'year' => '2015', 'people' => 'mary'}
) do |content|
  content << 'hello world.'
end

o = bucket.get_object('files/hello', :file => '/tmp/x')
puts "Get object: #{o.to_s}"

# 通过copy_object修改metas
bucket.copy_object('files/hello', 'files/hello',
                   :meta_directive => Aliyun::OSS::MetaDirective::REPLACE,
                   :metas => {'year' => '2016', 'people' => 'jack'})
o = bucket.get_object_meta('files/hello')
puts "Meta changed: #{o.to_s}"

# 设置Object的ACL
puts "Object acl before: #{bucket.get_object_acl('files/hello')}"
bucket.set_object_acl('files/hello', Aliyun::OSS::ACL::PUBLIC_READ)
puts "Object acl now: #{bucket.get_object_acl('files/hello')}"

# 指定条件get_object
o = bucket.get_object_meta('files/hello')
old_etag = o.etag

begin
  o = bucket.get_object('files/hello',
                        :condition => {:if_unmatch_etag => old_etag})
rescue Aliyun::OSS::ServerError => e
  puts "Get object failed: #{e.message}, #{e.http_code}"
end

begin
  o = bucket.get_object('files/hello',
                        :condition => {:if_modified_since => Time.now})
rescue Aliyun::OSS::ServerError => e
  puts "Get object failed: #{e.message}, #{e.http_code}"
end

o = bucket.get_object('files/hello',
                      :condition => {
                        :if_match_etag => old_etag,
                        :if_unmodified_since => Time.now})
puts "Get object: #{o.to_s}"
