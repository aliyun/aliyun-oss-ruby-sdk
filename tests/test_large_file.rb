# coding: utf-8
require 'minitest/autorun'
require 'benchmark'
require 'yaml'
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require 'aliyun/oss'

class TestObjectKey < Minitest::Test
  def setup
    conf_file = '~/.oss.yml'
    conf = YAML.load(File.read(File.expand_path(conf_file)))
    client = Aliyun::OSS::Client.new(
      :endpoint => conf['endpoint'],
      :cname => conf['cname'],
      :access_key_id => conf['id'],
      :access_key_secret => conf['key'])
    @bucket = client.get_bucket(conf['bucket'])
    @prefix = 'tests/large_file/'
  end

  def get_key(k)
    @prefix + k
  end

  def test_large_file_1gb
    key = get_key("large_file_1gb")
    Benchmark.bm(32) do |bm|
      bm.report("Upload with put_object: ") do
        @bucket.put_object(key, :file => './large_file_1gb')
      end

      bm.report("Upload with resumable_upload: ") do
        @bucket.resumable_upload(key, './large_file_1gb')
      end

      bm.report("Download with get_object: ") do
        @bucket.get_object(key, :file => './large_file_1gb')
      end

      bm.report("Download with resumable_download: ") do
        @bucket.resumable_download(key, './large_file_1gb')
      end
    end
  end

  def test_large_file_8gb
    key = get_key("large_file_8gb")
    Benchmark.bm(32) do |bm|
      bm.report("Upload with put_object: ") do
        @bucket.put_object(key, :file => './large_file_8gb')
      end

      bm.report("Upload with resumable_upload: ") do
        @bucket.resumable_upload(key, './large_file_8gb')
      end

      bm.report("Download with get_object: ") do
        @bucket.get_object(key, :file => './large_file_8gb')
      end

      bm.report("Download with resumable_download: ") do
        @bucket.resumable_download(key, './large_file_8gb')
      end
    end
  end
end
