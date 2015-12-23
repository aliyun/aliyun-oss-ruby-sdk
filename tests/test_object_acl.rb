require 'minitest/autorun'
require 'yaml'
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require 'aliyun/oss'

class TestObjectACL < Minitest::Test
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

    @prefix = "tests/object_acl/"
  end

  def get_key(k)
    "#{@prefix}#{k}"
  end

  def test_put_object
    key = get_key('put')

    @bucket.put_object(key, acl: Aliyun::OSS::ACL::PRIVATE)
    acl = @bucket.get_object_acl(key)

    assert_equal Aliyun::OSS::ACL::PRIVATE, acl

    @bucket.put_object(key, acl: Aliyun::OSS::ACL::PUBLIC_READ)
    acl = @bucket.get_object_acl(key)

    assert_equal Aliyun::OSS::ACL::PUBLIC_READ, acl
  end

  def test_append_object
    key = get_key('append-1')

    @bucket.append_object(key, 0, acl: Aliyun::OSS::ACL::PRIVATE)
    acl = @bucket.get_object_acl(key)

    assert_equal Aliyun::OSS::ACL::PRIVATE, acl

    key = get_key('append-2')

    @bucket.put_object(key, acl: Aliyun::OSS::ACL::PUBLIC_READ)
    acl = @bucket.get_object_acl(key)

    assert_equal Aliyun::OSS::ACL::PUBLIC_READ, acl
  end
end
