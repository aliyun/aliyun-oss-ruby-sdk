# -*- encoding: utf-8 -*-

require 'rest-client'

module Aliyun
  module OSS

    ##
    # 用于操作OSS资源（bucket, object等）的client
    #
    class Client

      include Logging

      # 构造OSS client，参数：
      # [host] 服务的endpoint
      # [id] 服务的access key id
      # [key] 服务的access key secret
      def initialize(host, id, key)
        @host, @id, @key = host, id, key
      end

      # 列出当前所有的bucket
      def list_bucket
        logger.info('begin list bucket')

        headers = {'Date' => Util.get_date}
        signature = Util.get_signature(@key, 'GET', headers, {})
        auth = "OSS #{@id}:#{signature}"
        headers.update({'Authorization' => auth})
        RestClient.get @host, headers

        logger.info('done list bucket')
      end

      private
      # 发送RESTful HTTP请求
      def send_request
      end

    end # Client

  end # OSS
end # Aliyun
