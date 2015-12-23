require 'minitest/autorun'
require 'yaml'
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require 'aliyun/oss'
require 'zlib'

class TestCustomHeaders < Minitest::Test
  def setup
    Aliyun::Common::Logging.set_log_level(Logger::DEBUG)
    conf_file = '~/.oss.yml'
    conf = YAML.load(File.read(File.expand_path(conf_file)))
    client = Aliyun::OSS::Client.new(
      :endpoint => conf['endpoint'],
      :cname => conf['cname'],
      :access_key_id => conf['access_key_id'],
      :access_key_secret => conf['access_key_secret'])
    @bucket = client.get_bucket(conf['bucket'])

    @prefix = "tests/custom_headers/"
  end

  def get_key(k)
    "#{@prefix}#{k}"
  end

  def test_custom_headers
    key = get_key('ruby')
    cache_control = 'max-age: 3600'
    @bucket.put_object(key, headers: {'cache-control' => cache_control})
    obj = @bucket.get_object(key)
    assert_equal cache_control, obj.headers[:cache_control]

    content_disposition = 'attachment; filename="fname.ext"'
    @bucket.put_object(
      key,
      headers: {'cache-control' => cache_control,
                'CONTENT-DISPOSITION' => content_disposition})
    obj = @bucket.get_object(key)
    assert_equal cache_control, obj.headers[:cache_control]
    assert_equal content_disposition, obj.headers[:content_disposition]

    content_encoding = 'deflate'
    expires = (Time.now + 3600).httpdate
    @bucket.put_object(
      key,
      headers: {'cache-control' => cache_control,
                'CONTENT-DISPOSITION' => content_disposition,
                'content-ENCODING' => content_encoding,
                'EXPIRES' => expires }) do |s|
      s << Zlib::Deflate.deflate('hello world')
    end

    content = ''
    obj = @bucket.get_object(key) { |c| content << c }
    assert_equal 'hello world', content
    assert_equal cache_control, obj.headers[:cache_control]
    assert_equal content_disposition, obj.headers[:content_disposition]
    assert_equal content_encoding, obj.headers[:content_encoding]
    assert_equal expires, obj.headers[:expires]
  end

  def test_headers_overwrite
    key = get_key('rails')
    @bucket.put_object(
      key,
      content_type: 'text/html',
      metas: {'hello' => 'world'},
      headers: {'content-type' => 'application/json',
                'x-oss-meta-hello' => 'bar'}) { |s| s << 'hello world' }
    obj = @bucket.get_object(key)

    assert_equal 'application/json', obj.headers[:content_type]
    assert_equal ({'hello' => 'bar'}), obj.metas
  end
end
