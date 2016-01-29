class TestConf
  class << self
    def creds
      {
        access_key_id: ENV['RUBY_SDK_OSS_ID'],
        access_key_secret: ENV['RUBY_SDK_OSS_KEY'],
        endpoint: ENV['RUBY_SDK_OSS_ENDPOINT']
      }
    end

    def bucket
      ENV['RUBY_SDK_OSS_BUCKET']
    end
  end
end
