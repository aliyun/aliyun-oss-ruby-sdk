# -*- encoding: utf-8 -*-

require 'nokogiri'

module Aliyun
  module OSS

    class Exception < RuntimeError

      include Logging

      attr_reader :http_code, :code, :message, :bucket_name, :request_id, :host_id

      def initialize(http_code, content)
        logger.debug("Exception HTTP code: #{http_code}, content: #{content}")

        @http_code = http_code
        @code = "Unknown Error"

        begin
          doc = Nokogiri::XML(content)
          error = doc.css('Error').first

          @code = get_node_text(error, 'Code')
          @message = get_node_text(error, 'Message')
          @bucket_name = get_node_text(error, 'BucketName')
          @request_id = get_node_text(error, 'RequestId')
          @host_id = get_node_text(error, 'HostId')
        rescue ::Exception => e
          @message = e.message
        end
      end

      def to_s
        "Code: #{code}, Message: #{message}, RequestID: #{request_id}.\n" +
          "HTTP code: #{http_code}, Bucket: #{bucket_name}, Host: #{host_id}"
      end

      private
      # 获取节点下面的tag内容
      def get_node_text(node, tag)
        node.css(tag).first.children.first.text
      end

    end # Exception
  end # OSS
end # Aliyun
