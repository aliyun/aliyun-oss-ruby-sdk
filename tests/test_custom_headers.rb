require 'minitest/autorun'
require 'yaml'
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require 'aliyun/oss'
require 'zlib'
require_relative 'config'

class TestCustomHeaders < Minitest::Test
  def setup
    Aliyun::Common::Logging.set_log_level(Logger::DEBUG)
    client = Aliyun::OSS::Client.new(TestConf.creds)
    @bucket = client.get_bucket(TestConf.bucket)

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
    obj = nil
    if @bucket.download_crc_enable
      assert_raises Aliyun::OSS::CrcInconsistentError do
        obj = @bucket.get_object(key) { |c| content << c }
      end
    else
      obj = @bucket.get_object(key) { |c| content << c }
      assert_equal 'hello world', content
      assert_equal cache_control, obj.headers[:cache_control]
      assert_equal content_disposition, obj.headers[:content_disposition]
      assert_equal content_encoding, obj.headers[:content_encoding]
      assert_equal expires, obj.headers[:expires]
    end
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

  def test_get_object_detailed_meta
    key = get_key('meta')
    object_content = 'hello, test_get_object_meta interface testing.'

    @bucket.put_object(
      key,
      content_type: 'text/html',
      metas: {'world' => 'Ruby.World', 'year' => '2017', 'people' => 'Jackie'},
      headers: {'content-type' => 'application/json',
                'Cache-Control' => '123456', 
                'x-oss-meta-hello' => 'hello.Bar'}) { |s| s << object_content }
    
    meta = @bucket.get_object_detailed_meta(key)

    assert_equal meta.class, Aliyun::OSS::Object
    assert_equal meta.key, key
    assert_equal meta.size, object_content.size
    assert meta.etag.upcase.include?(OpenSSL::Digest::MD5.hexdigest(object_content).upcase)
    assert_equal meta.headers[:x_oss_meta_year], '2017'
    assert_equal meta.headers[:x_oss_meta_people], 'Jackie'
    assert_equal meta.headers[:x_oss_meta_hello], 'hello.Bar'
    assert_equal meta.headers[:x_oss_meta_world], 'Ruby.World'
  end

  def test_udpate_object_metas
    key = get_key('meta')
    object_content = 'hello, test_get_object_meta interface testing.'

    @bucket.put_object(
      key,
      content_type: 'application/json',
      metas: { 'year' => '2017', 'people' => 'Jackie' },
      headers: {'content-type' => 'application/json',
                'x-oss-meta-hello' => 'hello.x-oss'}) { |s| s << object_content }
    
    @bucket.get_object_detailed_meta(key)

    headers_dict = {
      'Cache-Control' => '123456',
      'Content-Type' => 'text/html',
      'Content-Encoding' => 'downloading_code', 
      'Content-Language' => 'downloading_language_code', 
      'Content-Disposition' => 'content_disposition_downloading_name', 
      'Expires' => '2019-09-26' 
    }

    metas_dict = {
      'world': 'Ruby.World',
      'people': 'alibaba.man'
    }

    @bucket.update_object_metas(key, metas: metas_dict, headers: headers_dict)

    meta = @bucket.get_object_detailed_meta(key)

    assert_equal meta.class, Aliyun::OSS::Object
    assert_equal meta.key, key
    assert_equal meta.size, object_content.size
    assert meta.etag.upcase.include?(OpenSSL::Digest::MD5.hexdigest(object_content).upcase)
    assert_equal meta.headers[:cache_control], '123456'
    assert_equal meta.headers[:content_disposition], 'content_disposition_downloading_name'
    assert_equal meta.headers[:content_encoding], 'downloading_code'
    assert_equal meta.headers[:content_language], 'downloading_language_code'
    assert_equal meta.headers[:expires], '2019-09-26'
    assert_equal meta.headers[:x_oss_meta_people], 'alibaba.man'
    assert_equal meta.headers[:x_oss_meta_world], 'Ruby.World'
  end

end
