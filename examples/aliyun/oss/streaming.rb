# -*- encoding: utf-8 -*-

$LOAD_PATH.unshift(File.expand_path("../../../../lib", __FILE__))
require 'yaml'
require 'aliyun/oss'

##
# Generally speaking, when a user uploads or downloads objects with specifying a file:
# - In upload, client will upload the data of the file to OSS.
# - In download, client will download the data from OSS to the file locally.
#
# However in some scenarios, users may want to download or upload data in streaming:
# - Users cannot get the whole data for uploading, instead each time they get the partial data from up streaming and write it into OSS.
# - The data users want to write is computed and each compute just returns partial data. Typically Users dont want to compute all data and then write them as the whole
#   to OSS. Instead they wantt o compute some data and write the result to OSS immediately.
# - The object users want to download is too big to hold in memory. They want to download some data and then processs them without saving to local file.
#
# Of course, for streaming upload scenario, we can leverage appendable object to solve.
# However, even for normal object, by using SDK's streaming APIs, you can also achieve the streaming upload or download.

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

# Example1: merge sort
# There're two files sort.1 and sort.2 which have the sorted int. Every int occupies one line.
# Now you need to merge sort the two files into one file and uploaded it to OSS.

local_1, local_2 = 'sort.1', 'sort.2'
result_object = 'sort.all'

File.open(File.expand_path(local_1), 'w') do |f|
  [1001, 2005, 2007, 2011, 2013, 2015].each do |i|
    f.puts(i.to_s)
  end
end

File.open(File.expand_path(local_2), 'w') do |f|
  [2009, 2010, 2012, 2017, 2020, 9999].each do |i|
    f.puts(i.to_s)
  end
end

demo "Streaming upload" do
  bucket.put_object(result_object) do |content|
    f1 = File.open(File.expand_path(local_1))
    f2 = File.open(File.expand_path(local_2))
    v1, v2 = f1.readline, f2.readline

    until f1.eof? or f2.eof?
      if v1.to_i < v2.to_i
        content << v1
        v1 = f1.readline
      else
        content << v2
        v2 = f2.readline
      end
    end

    [v1, v2].sort.each{|i| content << i}
    content << f1.readline until f1.eof?
    content << f2.readline until f2.eof?
  end

  puts "Put object: #{result_object}"

  # download the file and print the content
  bucket.get_object(result_object, :file => result_object)
  puts "Get object: #{result_object}"
  puts "Content: #{File.read(result_object)}"
end

# Example 2: download progress bar
# Download a 10M file and print the download progress

large_file = 'large_file'

demo "Streaming download" do
  puts "Begin put object: #{large_file}"
  # Leverage streaming upload
  bucket.put_object(large_file) do |stream|
    10.times { stream << "x" * (1024 * 1024) }
  end

  # check object size
  object_size = bucket.get_object(large_file).size
  puts "Put object: #{large_file}, size: #{object_size}"

  # streaming download file, print the progress, but not save the file
  def to_percentile(v)
    "#{(v * 100.0).round(2)} %"
  end

  puts "Begin download: #{large_file}"
  last_got, got = 0, 0
  bucket.get_object(large_file) do |chunk|
    got += chunk.size
    # only print the progress when the progress is more than 10%.
    if (got - last_got).to_f / object_size > 0.1
      puts "Progress: #{to_percentile(got.to_f / object_size)}"
      last_got = got
    end
  end
  puts "Get object: #{large_file}, size: #{object_size}"
end
