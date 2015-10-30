# -*- encoding: utf-8 -*-

require 'rest-client'

module Aliyun
  module OSS

    class Client

      def initialize(host, id, key)
        @host, @id, @key = host, id, key
      end

      def list_bucket
        headers = {'Date' => Util.get_date}
        signature = Util.get_signature(@key, 'GET', headers, "", {})
        auth = "OSS #{@id}:#{signature}"
        headers.update({'Authorization' => auth})
        RestClient.get @host, headers
      end

    end # Client

  end # OSS
end # Aliyun
