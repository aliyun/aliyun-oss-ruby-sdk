# -*- encoding: utf-8 -*-

$LOAD_PATH.unshift(File.expand_path("../../../../lib", __FILE__))
require 'yaml'
require 'json'
require 'aliyun/oss'

##
# User could specify callback  when uploading a file so that OSS will issue a POST request to that callback url upon a successful file upload.
# This is one way of notification and user could do proper action on that callback request.
# 1. Check out the following file to know more about how to handle OSS's callback request.
#    rails/aliyun_oss_callback_server.rb
# 2. Only put_object and resumable_upload support upload callback.

# Initialize OSS client
Aliyun::Common::Logging.set_log_level(Logger::DEBUG)
conf_file = '~/.oss.yml'
conf = YAML.load(File.read(File.expand_path(conf_file)))
bucket = Aliyun::OSS::Client.new(
  :endpoint => conf['endpoint'],
  :cname => conf['cname'],
  :access_key_id => conf['access_key_id'],
  :access_key_secret => conf['access_key_secret']).get_bucket(conf['bucket'])

# print helper function
def demo(msg)
  puts "######### #{msg} ########"
  puts
  yield
  puts "-------------------------"
  puts
end

demo "put object with callback" do
  callback = Aliyun::OSS::Callback.new(
    url: 'http://10.101.168.94:1234/callback',
    query: {user: 'put_object'},
    body: 'bucket=${bucket}&object=${object}'
  )

  begin
    bucket.put_object('files/hello', callback: callback)
  rescue Aliyun::OSS::CallbackError => e
    puts "Callback failed: #{e.message}"
  end
end

demo "resumable upload with callback" do
  callback = Aliyun::OSS::Callback.new(
    url: 'http://10.101.168.94:1234/callback',
    query: {user: 'resumable_upload'},
    body: 'bucket=${bucket}&object=${object}'
  )

  begin
    bucket.resumable_upload('files/world', '/tmp/x', callback: callback)
  rescue Aliyun::OSS::CallbackError => e
    puts "Callback failed: #{e.message}"
  end
end
