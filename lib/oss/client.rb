# -*- encoding: utf-8 -*-

require 'rest-client'
require 'nokogiri'
require 'time'

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

        body = send_request('GET', '/', "")
        doc = Nokogiri::XML(body)
        buckets = doc.css("Buckets Bucket").map do |node|
          name = get_node_text(node, "Name")
          location = get_node_text(node, "Location")
          creation_time = Time.parse(get_node_text(node, "CreationDate"))
          Bucket.new(name, location, creation_time)
        end

        logger.info('done list bucket')

        buckets
      end

      private
      # 发送RESTful HTTP请求
      def send_request(verb, path, body)
        headers = {'Date' => Util.get_date}
        signature = Util.get_signature(@key, verb, headers, {})
        auth = "OSS #{@id}:#{signature}"
        headers.update({'Authorization' => auth})

        logger.debug("Send HTTP request, verb: #{verb}, path: #{path}, headers: #{headers}")

        r = RestClient::Request.execute(
          :method => verb,
          :url => @host + path,
          :headers => headers,
          :body => body)

        logger.debug("Received HTTP response, code: #{r.code}, headers: #{r.headers}, body: #{r.body}")

        r.body
      end

      # 获取节点下面的tag内容
      def get_node_text(node, tag)
        node.css(tag).first.children.first.text
      end

    end # Client

  end # OSS
end # Aliyun
