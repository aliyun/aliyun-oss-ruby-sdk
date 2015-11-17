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
        parse_endpoint if endpoint
      end

      private

      def parse_endpoint
        uri = URI.parse(endpoint)
        uri = URI.parse("http://#{endpoint}") unless uri.scheme

        raise ClientError.new("Only HTTP and HTTPS endpoint are accepted.") \
                             if uri.scheme != 'http' and uri.scheme != 'https'

        @endpoint = uri
      end

    end # Config
  end # OSS
end # Aliyun
