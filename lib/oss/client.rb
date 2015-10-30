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
        logger.info('Begin list bucket')

        body = send_request('GET')
        doc = Nokogiri::XML(body)
        buckets = doc.css("Buckets Bucket").map do |node|
          name = get_node_text(node, "Name")
          location = get_node_text(node, "Location")
          creation_time = Time.parse(get_node_text(node, "CreationDate"))
          Bucket.new(name, location, creation_time)
        end

        logger.info('Done list bucket')

        buckets
      end

      # 向名为bucket_name的bucket中添加一个object，名字为object_name，
      # object的内容由block提供
      # [bucket_name] bucket名字
      # [object_name] object名字
      # [block] 提供object的内容
      def put_object(bucket_name, object_name, &block)
        logger.info("Begin put object, bucket: #{bucket_name}, object:#{object_name}")

        content = ""
        block.call(content)
        send_request('PUT', bucket_name, object_name, content)

        logger.info('Done put object')
      end

      # 向名为bucket_name的bucket中添加一个object，名字为object_name，
      # object的内容从路径为file_path的文件读取
      # [bucket_name] bucket名字
      # [object_name] object名字
      # [file_path] 要读取的文件
      def put_object_from_file(bucket_name, object_name, file_path)
        logger.info("Begin put object from file: #{file_path}")

        put_object(bucket_name, object_name) do |content|
          content << File.read(file_path)
        end

        logger.info('Done put object from file')
      end

      # 列出指定的bucket中的所有object
      # [bucket_name] bucket的名字
      # [return] Object数组
      def list_object(bucket_name)
        logger.info("Begin list object, bucket: #{bucket_name}")

        body = send_request('GET', bucket_name)
        doc = Nokogiri::XML(body)
        objects = doc.css("Contents").map do |node|
          Object.new(
            :key => get_node_text(node, "Key"),
            :type => get_node_text(node, "Type"),
            :size => get_node_text(node, "Size").to_i,
            :etag => get_node_text(node, "ETag"),
            :last_modified => Time.parse(get_node_text(node, "LastModified")))
        end

        logger.info("Done list object")

        objects
      end

      private

      # 获取请求的URL，根据操作是否指定bucket和object，URL可能不同
      def get_request_url(bucket, object)
        url = ""
        url += "#{bucket}." if bucket
        url += @host
        url += "/#{object}" if object
        url
      end

      # 发送RESTful HTTP请求
      def send_request(verb, bucket = nil, object = nil, body = nil)
        headers = {'Date' => Util.get_date}
        headers['Content-Type'] = 'application/octet-stream' if body

        resources = {}
        if bucket
          res = "/#{bucket}/"
          res += "#{object}" if object
          resources[:res] = res
        end

        signature = Util.get_signature(@key, verb, headers, resources)
        auth = "OSS #{@id}:#{signature}"
        headers['Authorization']  = auth

        logger.debug("Send HTTP request, verb: #{verb}, bucket: #{bucket}, object: #{object}, headers: #{headers}")

        r = RestClient::Request.execute(
          :method => verb,
          :url => get_request_url(bucket, object),
          :headers => headers,
          :payload => body)

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
