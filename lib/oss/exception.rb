# -*- encoding: utf-8 -*-

require 'nokogiri'

module Aliyun
  module OSS

    # Base class for oss-sdk
    class Exception < RuntimeError
    end

    class ServerError < Exception
      include Logging

      attr_reader :http_code, :attrs

      def initialize(http_code, content)
        logger.debug("Exception HTTP code: #{http_code}, content: #{content}")

        @http_code = http_code
        @attrs = {}

        doc = Nokogiri::XML(content) do |config|
          config.options |= Nokogiri::XML::ParseOptions::NOBLANKS
        end rescue nil

        if doc
          doc.root.children.each do |n|
            @attrs[n.name] = n.text
          end
        end
      end

      def message
        @attrs['Message'] || "InternalError"
      end

      def to_s
        @attrs.merge({'HTTPCode' => @http_code}).map do |k, v|
          [k, v].join(": ")
        end.join(", ")
      end

      private
      # 获取节点下面的tag内容
      def get_node_text(node, tag)
        node.css(tag).first.children.first.text
      end

    end # Exception

    class ClientError < Exception
      attr_reader :message

      def initialize(message)
        @message = message
      end
    end # SDKException

  end # OSS
end # Aliyun
