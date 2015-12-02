require 'minitest/autorun'
require 'yaml'
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require 'aliyun/oss'

class TestResumable < Minitest::Test
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
    @prefix = 'tests/resumable/'
  end

  def get_key(k)
    @prefix + k
  end

  def random_string(n)
    (1...n).map { (65 + rand(26)).chr }.join + "\n"
  end

  def test_correctness
    key = get_key('resumable')
    # generate 10M random data
    File.open('/tmp/x', 'w') do |f|
      (10 * 1024).times { f.write(random_string(1024)) }
    end

    @bucket.resumable_upload(key, '/tmp/x', :part_size => 100 * 1024)
    @bucket.resumable_download(key, '/tmp/y', :part_size => 100 * 1024)

    diff = `diff /tmp/x /tmp/y`
    assert diff.empty?, diff
  end
end
