# coding: utf-8
require 'minitest/autorun'
require 'yaml'
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require 'aliyun/oss'

class TestObjectKey < Minitest::Test
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
    @prefix = 'tests/object_key/'
    @keys = {
      simple: 'simple_key',
      chinese: '杭州・中国',
      space: '是 空格 yeah +-/\\&*#',
      invisible: '' << 1 << 10 << 12 << 7,
    }
  end

  def get_key(sym)
    @prefix + @keys[sym]
  end

  def test_simple
    key = get_key(:simple)
    @bucket.put_object(key)
    all = @bucket.list_objects(prefix: @prefix).map(&:key)
    assert_includes all, key
    assert_equal key, @bucket.get_object(key).key
  end

  def test_chinese
    key = get_key(:chinese)
    @bucket.put_object(key)
    all = @bucket.list_objects(prefix: @prefix).map(&:key)
    assert_includes all, key
    assert_equal key, @bucket.get_object(key).key
  end

  def test_space
    key = get_key(:space)
    @bucket.put_object(key)
    all = @bucket.list_objects(prefix: @prefix).map(&:key)
    assert_includes all, key
    assert_equal key, @bucket.get_object(key).key
  end

  def test_invisible
    key = get_key(:invisible)
    @bucket.put_object(key)
    all = @bucket.list_objects(prefix: @prefix).map(&:key)
    assert_includes all, key
    assert_equal key, @bucket.get_object(key).key
  end

  def test_batch_delete
    keys = @keys.map { |k, _| get_key(k) }
    keys.each { |k| @bucket.put_object(k) }
    ret = @bucket.batch_delete_objects(keys)
    assert_equal keys, ret
    all = @bucket.list_objects(prefix: @prefix).map(&:key)
    assert all.empty?, all.to_s
  end
end
