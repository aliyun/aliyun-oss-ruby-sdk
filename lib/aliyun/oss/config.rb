# -*- encoding: utf-8 -*-

module Aliyun
  module OSS

    ##
    # A place to store various configurations: credentials, api
    # timeout, retry mechanism, etc
    #
    class Config
      @options = {}

      class << self
        def get(key)
          @options[key]
        end

        # Setup access key id and access key secret
        def set_credentials(access_id, access_key)
          @options.update(
            { :access_id => access_id,
              :access_key => access_key })
        end

        # Setup endpoint
        def set_endpoint(endpoint, cname = false)
          uri = URI.parse(endpoint)
          uri = URI.parse("http://#{endpoint}") unless uri.scheme

          raise ClientError.new("Only HTTP and HTTPS endpoint are accepted.") \
                               if uri.scheme != 'http' and uri.scheme != 'https'

          @options[:endpoint] = uri
          @options[:cname] = cname
        end

      end # self
    end # Config
  end # OSS
end # Aliyun
