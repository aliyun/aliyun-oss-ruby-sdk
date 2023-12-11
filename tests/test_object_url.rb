require 'minitest/autorun'
require 'yaml'
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require 'aliyun/oss'
require 'aliyun/sts'
require 'rest-client'
require_relative 'config'

class TestObjectUrl < Minitest::Test
  def setup
    Aliyun::Common::Logging.set_log_level(Logger::DEBUG)
    client = Aliyun::OSS::Client.new(TestConf.creds)
    @bucket = client.get_bucket(TestConf.bucket)

    @prefix = "tests/object_url/"
  end

  def get_key(k)
    "#{@prefix}#{k}"
  end

  def test_signed_url_for_get
    key = get_key('object-for-get')

    @bucket.put_object(key, acl: Aliyun::OSS::ACL::PRIVATE)

    plain_url = @bucket.object_url(key, false)
    begin
      r = RestClient.get(plain_url)
      assert false, 'GET plain object url should receive 403'
    rescue => e
      assert_equal 403, e.response.code
    end

    signed_url = @bucket.object_url(key)
    r = RestClient.get(signed_url)

    assert_equal 200, r.code
  end

  def test_signed_url_with_sts
    key = get_key('object-with-sts')

    sts_client = Aliyun::STS::Client.new(TestConf.sts_creds)
    token = sts_client.assume_role(TestConf.sts_role, 'app')

    bucket = Aliyun::OSS::Client.new(
      :endpoint => TestConf.creds[:endpoint],
      :sts_token => token.security_token,
      :access_key_id => token.access_key_id,
      :access_key_secret => token.access_key_secret)
             .get_bucket(TestConf.sts_bucket)

    bucket.put_object(key, acl: Aliyun::OSS::ACL::PRIVATE)

    plain_url = bucket.object_url(key, false)
    begin
      r = RestClient.get(plain_url)
      assert false, 'GET plain object url should receive 403'
    rescue => e
      assert_equal 403, e.response.code
    end

    signed_url = bucket.object_url(key)
    r = RestClient.get(signed_url)

    assert_equal 200, r.code
  end

  def test_signed_url_with_parameters
    key = get_key('example.jpg')

    @bucket.put_object(key, :file => 'tests/example.jpg', acl: Aliyun::OSS::ACL::PRIVATE)

    meta = @bucket.get_object(key)
    assert_equal 21839, meta.size 

    parameters = {
      'x-oss-process' => 'image/resize,m_fill,h_100,w_100',
    }
    signed_url = @bucket.object_url(key, true, 60, parameters)
    r = RestClient.get(signed_url)
    lenth = r.headers[:content_length].to_i
    assert_equal 200, r.code
    assert_equal true, lenth < meta.size

  end

  def test_signed_url_with_name_check
    parameters = {
      'x-oss-process' => 'image/resize,m_fill,h_100,w_100',
    }
    key = '?'
    begin
      signed_url = @bucket.object_url(key, true, 60, parameters)
      assert false, 'Shoud not here'
    rescue => e
      assert_equal "The object name cannot start with '?'.", e.message
    end

    key = '?123'
    begin
      signed_url = @bucket.object_url(key, true, 60, parameters)
      assert false, 'Shoud not here'
    rescue => e
      assert_equal "The object name cannot start with '?'.", e.message
    end

    key = ''
    begin
      signed_url = @bucket.object_url(key, true, 60, parameters)
      assert false, 'Shoud not here'
    rescue => e
      assert_equal "The object name is invalid.", e.message
    end

    client1 = Aliyun::OSS::Client.new(
      endpoint: 'https://oss-cn-hangzhou.aliyuncs.com',
      access_key_id: 'ak',
      access_key_secret: 'sk',
      verify_object_strict: false
    )
    @bucket1 = client1.get_bucket(TestConf.bucket)

    key = '?'
    begin
      signed_url = @bucket1.object_url(key, true, 60, parameters)
      assert_equal true, signed_url.include?('/%3F?')
    rescue => e
      assert false, 'Shoud not here'
    end

    key = '?123'
    begin
      signed_url = @bucket1.object_url(key, true, 60, parameters)
      assert_equal true, signed_url.include?('/%3F123?')
    rescue => e
      assert false, 'Shoud not here'
    end
  end

end
