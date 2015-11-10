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

      def initialize(response)
        @http_code = response.code
        @attrs = {'RequestId' => get_request_id(response)}

        doc = Nokogiri::XML(response.body) do |config|
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
        n = node.at_css(tag) if node
        value = n.text if n
        value
      end

      def get_request_id(response)
        r = response.headers[:x_oss_request_id] if response.headers
        r.to_s
      end

    end # Exception

    class ClientError < Exception
      attr_reader :message

      def initialize(message)
        @message = message
      end
    end # SDKException

    class FileInconsistentError < ClientError; end
    class ObjectInconsistentError < ClientError; end
    class PartMissingError < ClientError; end
    class PartInconsistentError < ClientError; end
    class TokenInconsistentError < ClientError; end

  end # OSS
end # Aliyun
