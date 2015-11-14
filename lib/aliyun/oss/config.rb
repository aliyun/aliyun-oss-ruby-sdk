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
        def set_endpoint(endpoint)
          @options[:endpoint] = endpoint
        end

      end

    end # Config

  end # OSS
end # Aliyun
