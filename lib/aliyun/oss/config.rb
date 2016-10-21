# -*- encoding: utf-8 -*-

module Aliyun
  module OSS

    ##
    # A place to store various configurations: credentials, api
    # timeout, retry mechanism, etc
    #
    class Config < Common::Struct::Base

      attrs :endpoint, :cname, :sts_token,
            :access_key_id, :access_key_secret,
            :open_timeout, :read_timeout,
            :crc_enable

      def initialize(opts = {})
        super(opts)

        @access_key_id = @access_key_id.strip if @access_key_id
        @access_key_secret = @access_key_secret.strip if @access_key_secret
        normalize_endpoint if endpoint
        @crc_enable ||= false
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
