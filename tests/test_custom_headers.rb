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
    
    obj = @bucket.get_object_detailed_meta(key)

    assert_equal obj.class, Aliyun::OSS::Object
    assert_equal obj.key, key
    assert_equal obj.size, object_content.size
    assert obj.etag.upcase.include?(OpenSSL::Digest::MD5.hexdigest(object_content).upcase)
    assert_equal obj.headers[:x_oss_meta_year], '2017'
    assert_equal obj.headers[:x_oss_meta_people], 'Jackie'
    assert_equal obj.headers[:x_oss_meta_hello], 'hello.Bar'
    assert_equal obj.headers[:x_oss_meta_world], 'Ruby.World'
    assert_equal obj.headers[:content_type], 'application/json'
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
    
    metas_dict = {
      'world'  => 'Ruby.World.update_object_metas',
      'people' => 'alibaba.man.mama',
      'year'   => '2050',
    }

    @bucket.update_object_metas(key, metas_dict)

    obj = @bucket.get_object_detailed_meta(key)

    assert_equal obj.class, Aliyun::OSS::Object
    assert_equal obj.key, key
    assert_equal obj.size, object_content.size
    assert obj.etag.upcase.include?(OpenSSL::Digest::MD5.hexdigest(object_content).upcase)
    assert_equal obj.headers[:x_oss_meta_people], 'alibaba.man.mama'
    assert_equal obj.headers[:x_oss_meta_world], 'Ruby.World.update_object_metas'
    assert_equal obj.headers[:x_oss_meta_year], '2050'
    assert_nil   obj.headers[:x_oss_meta_hello]
    assert_equal obj.headers[:content_type], 'application/octet-stream'
  end

  def test_copy_object_for_update_headers
    key = get_key('meta')
    object_content = 'hello, test_get_object_meta interface testing.'

    @bucket.put_object(
      key,
      content_type: 'application/json',
      metas: { 'year' => '2017', 'people' => 'Jackie', 'hello' => 'hello.in_metas_by_put' },
      headers: {'content-type' => 'application/json',
                'Content-Encoding' => 'downloading_code_set_by_put_object',
                'x-oss-meta-hello' => 'hello.x-oss.in_headers_by_put'}) { |s| s << object_content }
    
    obj_put = @bucket.get_object_detailed_meta(key)
    assert_equal obj_put.class, Aliyun::OSS::Object
    assert_equal obj_put.key, key
    assert_equal obj_put.size, object_content.size
    assert_equal obj_put.headers[:x_oss_meta_hello], 'hello.x-oss.in_headers_by_put'
    assert_equal obj_put.headers[:x_oss_meta_people], 'Jackie'
    assert_equal obj_put.headers[:x_oss_meta_year], '2017'
    assert_equal obj_put.headers[:content_type], 'application/json'
    assert_equal obj_put.headers[:content_encoding], 'downloading_code_set_by_put_object'

    headers_dict = {
      'Cache-Control' => '1234567890',
      'Content-Type' => 'text/html',
      'Content-Encoding' => 'downloading_code', 
      'Content-Language' => 'downloading_language_code', 
      'Content-Disposition' => 'content_disposition_downloading_name', 
      'Expires' => '2029-11-22',
      'hello' => 'hello_in_headers_without_x_oss_meta',
      'x-oss-meta-hello' => 'hello_in_headers_with_x_oss_meta', 
    }
    metas_dict = {
      'world'  => 'Ruby.World',
      'people' => 'alibaba.man',
      'hello'  => 'hello_in_metas',
    }
    args = { :meta_directive => Aliyun::OSS::MetaDirective::REPLACE, :metas => metas_dict, :headers => headers_dict }

    @bucket.copy_object(key, key, args)

    obj = @bucket.get_object_detailed_meta(key)

    assert_equal obj.class, Aliyun::OSS::Object
    assert_equal obj.key, key
    assert_equal obj.size, object_content.size
    assert obj.etag.upcase.include?(OpenSSL::Digest::MD5.hexdigest(object_content).upcase)
    assert_equal obj.headers[:content_type], 'text/html'
    assert_equal obj.headers[:cache_control], '1234567890'
    assert_equal obj.headers[:content_disposition], 'content_disposition_downloading_name'
    assert_equal obj.headers[:content_encoding], 'downloading_code'
    assert_equal obj.headers[:content_language], 'downloading_language_code'
    assert_equal obj.headers[:expires], '2029-11-22'
    assert_equal obj.headers[:x_oss_meta_hello], 'hello_in_headers_with_x_oss_meta'
    assert_equal obj.headers[:x_oss_meta_people], 'alibaba.man'
    assert_equal obj.headers[:x_oss_meta_world], 'Ruby.World'
    assert_nil   obj.headers[:hello]
  end

end
