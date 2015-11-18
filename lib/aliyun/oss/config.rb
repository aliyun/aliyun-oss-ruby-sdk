# -*- encoding: utf-8 -*-

module Aliyun
  module OSS

    ##
    # A place to store various configurations: credentials, api
    # timeout, retry mechanism, etc
    #
    class Config < Struct::Base

      attrs :endpoint, :cname, :access_key_id, :access_key_secret

      def initialize(opts = {})
        super(opts)
        normalize_endpoint if endpoint
      end

      private

      def normalize_endpoint
        uri = URI.parse(endpoint)
        uri = URI.parse("http://#{endpoint}") unless uri.scheme

        if uri.scheme != 'http' and uri.scheme != 'https'
          fail ClientError, "Only HTTP and HTTPS endpoint are accepted."
        end

        @endpoint = uri
      end

    end # Config
  end # OSS
end # Aliyun
