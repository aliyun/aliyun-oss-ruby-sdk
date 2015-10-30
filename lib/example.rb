# -*- encoding: utf-8 -*-

require 'yaml'
require_relative 'oss'

cred_file = "~/.oss.yml"
cred = YAML.load(File.read(File.expand_path(cred_file)))

Aliyun::OSS::Logging.set_log_level(Logger::DEBUG)

oss = Aliyun::OSS::Client.new('oss.aliyuncs.com', cred["id"], cred["key"])

puts "All buckets:"
oss.list_bucket.each do |bucket|
  puts "Bucket: #{bucket.name}, location: #{bucket.location}"
end

object = "hello"
oss.put_object('t-mail', object) do |content|
  content << "hello world"
end
puts "Put object: #{object} success"

object = "world"
oss.put_object_from_file('t-mail', object, '/tmp/x')
puts "Put object: #{object} success"

puts "All objects:"
oss.list_object('t-mail').each do |o|
  puts "Object: #{o.key}, size: #{o.size}"
end
