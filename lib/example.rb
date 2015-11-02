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
oss.list_bucket.each do |bucket|
  msg "Bucket: #{bucket.name}, location: #{bucket.location}"
end

# create a bucket: t-hello-world
bucket = 't-hello-world'
oss.create_bucket(:name => bucket, :location => 'oss-cn-hangzhou')
msg "Create bucket: #{bucket} success"

# put an object: hello
object = "hello"
oss.put_object(bucket, object) do |content|
  content << "hello world"
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
oss.list_object(bucket).each {|o| object_size = o.size if o.key == object}
oss.append_object(bucket, object, object_size) do |content|
  content << "hello, rails.\n"
end
msg "Append object: #{object} success"

# list all objects
msg "All objects:"
oss.list_object(bucket).each do |o|
  msg "Object: #{o.key}, type: #{o.type}, size: #{o.size}"
end

# get object 'rails' to file: /tmp/x
object = 'rails'
oss.get_object_to_file(bucket, object, '/tmp/x')
msg "Get object: #{object} success"

# delete the bucket
oss.delete_bucket(bucket)
msg "Delete bucket: #{bucket} success"
