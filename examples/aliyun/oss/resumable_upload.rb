# -*- encoding: utf-8 -*-

$LOAD_PATH.unshift(File.expand_path("../../../../lib", __FILE__))
require 'yaml'
require 'aliyun/oss'

# Initialize OSS Bucket
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

demo "Resumable upload" do
  puts "Generate file: /tmp/x, size: 100MB"
  # Create a 100M file
  File.open('/tmp/x', 'w') do |f|
    (1..1024*1024).each{ |i| f.puts i.to_s.rjust(99, '0') }
  end

  cpt_file = '/tmp/x.cpt'
  File.delete(cpt_file) if File.exist?(cpt_file)

  # Upload a 100M file
  start = Time.now
  puts "Start upload: /tmp/x => resumable"
  bucket.resumable_upload(
    'resumable', '/tmp/x', :cpt_file => cpt_file) do |progress|
    puts "Progress: #{(progress * 100).round(2)} %"
  end
  puts "Upload complete. Cost: #{Time.now - start} seconds."

  # Test steps:
  # 1. ruby examples/resumable_upload.rb
  # 2. Type Ctrl-C to distrupt the upload after a few seconds
  # 3. run ruby examples/resumable_upload.rb to recover the upload
end
