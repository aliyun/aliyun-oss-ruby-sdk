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

demo "Resumable download" do
  # Download a 100M file
  cpt_file = '/tmp/y.cpt'
  File.delete(cpt_file) if File.exist?(cpt_file)
  start = Time.now
  puts "Start download: resumable => /tmp/y"
  bucket.resumable_download(
    'resumable', '/tmp/y', :cpt_file => cpt_file) do |progress|
    puts "Progress: #{(progress * 100).round(2)} %"
  end
  puts "Download complete. Cost: #{Time.now - start} seconds."

  # test method：
  # 1. ruby examples/resumable_download.rb
  # 2. after a few seconds, type Ctrl-C to disrupt the download.
  # 3. ruby examples/resumable_download.rb to recover the download
end
