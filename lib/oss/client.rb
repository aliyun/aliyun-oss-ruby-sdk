# -*- encoding: utf-8 -*-

module Aliyun
  module OSS

    ##
    # OSS服务的客户端，用于获取bucket列表，连接到指定的bucket。
    #
    class Client

      include Logging

      # 构造OSS client，用于操作buckets。
      # @param endpoint [String] OSS服务的endpoint，例如：
      # @example
      #   oss-cn-hangzhou.aliyuncs.com
      # @param access_key_id [String] access key id
      # @param access_key_secret [String] access key secret
      # @return [Bucket] Bucket对象
      def initialize(endpoint, access_key_id, access_key_secret)
        Config.set_endpoint(endpoint)
        Config.set_credentials(access_key_id, access_key_secret)
      end

      # 列出当前所有的bucket
      # @param opts [Hash] 查询选项
      # @option opts [String] :prefix 如果设置，则只返回以它为前缀的bucket
      # @return [Enumerator<Bucket>] Bucket的迭代器
      def list_buckets(opts = {})
        Protocol.list_buckets(opts)
      end

      # 获取一个Bucket对象，用于操作bucket中的objects。
      # @param name [String] Bucket名字
      # @return [Bucket] Bucket对象
      def get_bucket(name)
        Bucket.new(:name => name)
      end

      # 通过endpoint直接连到到一个Bucket
      # @param name [String] Bucket名字
      # @param endpoint [String] Bucket的endpoint，例如：
      # @example
      #   bucket.oss-cn-hangzhou.aliyuncs.com
      # @param access_key_id [String] access key id
      # @param access_key_secret [String] access key secret
      # @return [Bucket] Bucket对象
      def self.connect_to_bucket(name, endpoint, access_key_id, access_key_secret)
        Config.set_endpoint(endpoint)
        Config.set_credentials(access_key_id, access_key_secret)
        Bucket.new(:name => name)
      end
    end # Client

  end # OSS
end # Aliyun
