# -*- encoding: utf-8 -*-

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
        Config.set_endpoint(host)
        Config.set_credentials(id, key)
      end

      def method_missing(name, *args, &block)
        Protocol.send(name, *args, &block)
      end

    end # Client

  end # OSS
end # Aliyun
