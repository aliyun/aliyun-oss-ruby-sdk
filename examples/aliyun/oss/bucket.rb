# -*- encoding: utf-8 -*-

$LOAD_PATH.unshift(File.expand_path("../../../../lib", __FILE__))
require 'yaml'
require 'aliyun/oss'

# Initialize OSS client
Aliyun::Common::Logging.set_log_level(Logger::DEBUG)
conf_file = '~/.oss.yml'
conf = YAML.load(File.read(File.expand_path(conf_file)))
client = Aliyun::OSS::Client.new(
  :endpoint => conf['endpoint'],
  :cname => conf['cname'],
  :access_key_id => conf['access_key_id'],
  :access_key_secret => conf['access_key_secret'])
bucket = client.get_bucket(conf['bucket'])

# print helper function
def demo(msg)
  puts "######### #{msg} ########"
  puts
  yield
  puts "-------------------------"
  puts
end

# list all buckets
demo "List all buckets" do
  buckets = client.list_buckets
  buckets.each{ |b| puts "Bucket: #{b.name}"}
end

# create bucket. If the bucket already exists, the creation will fail
demo "Create bucket" do
  begin
    bucket_name = 't-foo-bar'
    client.create_bucket(bucket_name, :location => 'oss-cn-hangzhou')
    puts "Create bucket success: #{bucket_name}"
  rescue => e
    puts "Create bucket failed: #{bucket_name}, #{e.message}"
  end
end

# add 5 empty objects into bucket:
# foo/obj1, foo/bar/obj1, foo/bar/obj2, foo/xxx/obj1

demo "Put objects before list" do
  bucket.put_object('foo/obj1')
  bucket.put_object('foo/bar/obj1')
  bucket.put_object('foo/bar/obj2')
  bucket.put_object('foo/xxx/obj1')
  bucket.put_object('中国の')
end

# list bucket's all objects
demo "List first 10 objects" do
  objects = bucket.list_objects

  objects.take(10).each do |o|
    puts "Object: #{o.key}, type: #{o.type}, size: #{o.size}"
  end
end

# list bucket's all object whose name has the prefix foo/bar/
demo "List first 10 objects with prefix 'foo/bar/'" do
  objects = bucket.list_objects(:prefix => 'foo/bar/')

  objects.take(10).each do |o|
    puts "Object: #{o.key}, type: #{o.type}, size: #{o.size}"
  end
end

# get common prefix of the object. Common prefix object is the object whose name is the common prefix of some other objects in the bucket.
# Essentially it's a 'folder' in the bucket.
# For example, if we have the following objects:
#     /foo/bar/obj1
#     /foo/bar/obj2
#     ...
#     /foo/bar/obj9999999
#     /foo/xx/
# Specify the prefix as foo/ and delimiter as '/', then the retirned common prefix is 
# /foo/bar/ and /foo/xxx/
# They could represent the subfolder of '/foo' folder. It's a efficient way to enumerate all files under a folder by specifying the common prefix.

demo "List first 10 objects/common prefixes" do
  objects = bucket.list_objects(:prefix => 'foo/', :delimiter => '/')

  objects.take(10).each do |o|
    if o.is_a?(Aliyun::OSS::Object)
      puts "Object: #{o.key}, type: #{o.type}, size: #{o.size}"
    else
      puts "Common prefix: #{o}"
    end
  end
end

# get/set Bucket attributes: ACL, Logging, Referer, Website, LifeCycle, CORS
demo "Get/Set bucket properties: ACL/Logging/Referer/Website/Lifecycle/CORS" do
  puts "Bucket acl before: #{bucket.acl}"
  bucket.acl = Aliyun::OSS::ACL::PUBLIC_READ
  puts "Bucket acl now: #{bucket.acl}"
  puts

  puts "Bucket logging before: #{bucket.logging.to_s}"
  bucket.logging = Aliyun::OSS::BucketLogging.new(
    :enable => true, :target_bucket => conf['bucket'], :target_prefix => 'foo/')
  puts "Bucket logging now: #{bucket.logging.to_s}"
  puts

  puts "Bucket referer before: #{bucket.referer.to_s}"
  bucket.referer = Aliyun::OSS::BucketReferer.new(
    :allow_empty => true, :whitelist => ['baidu.com', 'aliyun.com'])
  puts "Bucket referer now: #{bucket.referer.to_s}"
  puts

  puts "Bucket website before: #{bucket.website.to_s}"
  bucket.website = Aliyun::OSS::BucketWebsite.new(
    :enable => true, :index => 'default.html', :error => 'error.html')
  puts "Bucket website now: #{bucket.website.to_s}"
  puts

  puts "Bucket lifecycle before: #{bucket.lifecycle.map(&:to_s)}"
  bucket.lifecycle = [
    Aliyun::OSS::LifeCycleRule.new(
    :id => 'rule1', :enable => true, :prefix => 'foo/', :expiry => 1),
    Aliyun::OSS::LifeCycleRule.new(
      :id => 'rule2', :enable => false, :prefix => 'bar/', :expiry => Date.new(2016, 1, 1))
  ]
  puts "Bucket lifecycle now: #{bucket.lifecycle.map(&:to_s)}"
  puts

  puts "Bucket cors before: #{bucket.cors.map(&:to_s)}"
  bucket.cors = [
    Aliyun::OSS::CORSRule.new(
    :allowed_origins => ['aliyun.com', 'http://www.taobao.com'],
    :allowed_methods => ['PUT', 'POST', 'GET'],
    :allowed_headers => ['Authorization'],
    :expose_headers => ['x-oss-test'],
    :max_age_seconds => 100)
  ]
  puts "Bucket cors now: #{bucket.cors.map(&:to_s)}"
  puts
end
