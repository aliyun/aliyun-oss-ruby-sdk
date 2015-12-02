# coding: utf-8
require 'minitest/autorun'
require 'yaml'
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require 'aliyun/oss'

class TestEncoding < Minitest::Test
  def setup
    Aliyun::OSS::Logging.set_log_level(Logger::DEBUG)
    conf_file = '~/.oss.yml'
    conf = YAML.load(File.read(File.expand_path(conf_file)))
    client = Aliyun::OSS::Client.new(
      :endpoint => conf['endpoint'],
      :cname => conf['cname'],
      :access_key_id => conf['access_key_id'],
      :access_key_secret => conf['access_key_secret'])
    @bucket = client.get_bucket(conf['bucket'])
    @prefix = 'tests/encoding/'
  end

  def get_key(k)
    @prefix + k
  end

  def test_utf_8
    key = get_key('utf-8')
    @bucket.put_object(key) do |stream|
      stream << '中国' << 'Ruby'
    end
    put = '中国Ruby'.force_encoding(Encoding::ASCII_8BIT)
    got = ''
    @bucket.get_object(key) { |c| got << c }
    assert_equal put, got

    File.open('/tmp/x', 'w') { |f| f.write('中国Ruby') }
    @bucket.put_object(key, :file => '/tmp/x')
    got = ''
    @bucket.get_object(key) { |c| got << c }
    assert_equal put, got
  end

  def test_gbk
    key = get_key('gbk')
    @bucket.put_object(key) do |stream|
      stream << '中国'.encode(Encoding::GBK) << 'Ruby'.encode(Encoding::GBK)
    end
    put = '中国Ruby'.encode(Encoding::GBK).force_encoding(Encoding::ASCII_8BIT)
    got = ''
    @bucket.get_object(key) { |c| got << c }
    assert_equal put, got

    File.open('/tmp/x', 'w') { |f| f.write('中国Ruby'.encode(Encoding::GBK)) }
    @bucket.put_object(key, :file => '/tmp/x')
    got = ''
    @bucket.get_object(key) { |c| got << c }
    assert_equal put, got
  end

  def encode_number(i)
    [i].pack('N')
  end

  def test_binary
    key = get_key('bin')
    @bucket.put_object(key) do |stream|
      (0..1024).each { |i| stream << encode_number(i) }
    end
    put = (0..1024).reduce('') { |s, i| s << encode_number(i) }
    got = ''
    @bucket.get_object(key) { |c| got << c }
    assert_equal put, got

    File.open('/tmp/x', 'w') { |f|
      (0..1024).each { |i| f.write(encode_number(i)) }
    }
    @bucket.put_object(key, :file => '/tmp/x')
    got = ''
    @bucket.get_object(key) { |c| got << c }
    assert_equal put, got
  end
end
