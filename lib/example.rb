# -*- encoding: utf-8 -*-

require 'yaml'
require_relative 'oss'

def msg(s)
  puts "MESSAGE: #{s}"
end

cred_file = "~/.oss.yml"
cred = YAML.load(File.read(File.expand_path(cred_file)))

Aliyun::OSS::Logging.set_log_level(Logger::DEBUG)

oss = Aliyun::OSS::Client.new('oss.aliyuncs.com', cred["id"], cred["key"])

# list all buckets
msg "All buckets:"
buckets, _ = oss.list_bucket
buckets.each do |bucket|
  msg "Bucket: #{bucket.name}, location: #{bucket.location}"
end

# list all buckets
msg "List buckets prefixed with 't-':"
buckets, _ = oss.list_bucket(:prefix => 't-', :limit => 5)
buckets.each do |bucket|
  msg "Bucket: #{bucket.name}, location: #{bucket.location}"
end

# create a bucket: t-hello-world
bucket = 't-hello-world'
oss.create_bucket(bucket, :location => 'oss-cn-hangzhou')
msg "Create bucket: #{bucket} success"

# put an object: hello
object = "hello"
oss.put_object(bucket, object) do |content|
  content.write_and_finish "hello world"
end
msg "Put object: #{object} success"

# put and object from file: ruby
object = "ruby"
oss.put_object_from_file(bucket, object, __FILE__)
msg "Put object: #{object} success"

# copy object 'hello' to 'world'
src_object = 'hello'
dst_object = 'world'
oss.copy_object(bucket, src_object, dst_object)
msg "Copy object: #{src_object} => #{dst_object} success"

# delete an object: hello
object = 'hello'
oss.delete_object(bucket, object)
msg "Delete object: #{object} success"

# append an object: rails
object = "rails"
object_size = 0
objects, _ = oss.list_object(bucket)
objects.each {|o| object_size = o.size if o.key == object}
oss.append_object(bucket, object, object_size) do |content|
  content.write_and_finish "hello, rails.\n"
end
msg "Append object: #{object} success"

# list all objects
msg "All objects:"
objects, _ = oss.list_object(bucket)
objects.each do |o|
  msg "Object: #{o.key}, type: #{o.type}, size: #{o.size}"
end

# list objects with prefix and delimiter
# put objects: foo/bar/obj1, foo/bar/obj2, foo/xxx/obj1
oss.put_object(bucket, 'foo/bar/obj1') do |content|
  content.write_and_finish "foo/bar/obj1"
end

oss.put_object(bucket, 'foo/bar/obj2') do |content|
  content.write_and_finish "foo/bar/obj2"
end

oss.put_object(bucket, 'foo/xxx/obj1') do |content|
  content.write_and_finish "foo/xxx/obj1"
end

msg "List objects with prefix 'foo/' and delimiter '/' "
objects, more = oss.list_object(bucket, :prefix => 'foo/', :delimiter => '/')
objects.each do |o|
  msg "Object: #{o.key}, type: #{o.type}, size: #{o.size}"
end

(more[:common_prefixes] || []).each do |p|
  msg "Prefix: #{p}"
end

# get object 'rails' to file: /tmp/x
object = 'rails'
oss.get_object_to_file(bucket, object, '/tmp/x')
msg "Get object: #{object} success"

# delete the bucket
oss.delete_bucket(bucket)
msg "Delete bucket: #{bucket} success"
