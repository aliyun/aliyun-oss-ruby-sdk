# -*- encoding: utf-8 -*-

require 'rest-client'

module Aliyun
  module OSS

    ##
    # 封装了基本的HTTP请求功能：GET/PUT/POST/DELETE/HEAD
    # 也包含了streaming PUT/GET等高级特性
    # * Set :body to HTTP::StreamReader.new(block) to streaming
    # request body
    # * Pass block(chunk) to do_request to streaming response body
    #
    class HTTP

      ##
      # 实现了:read方法的一个stream实现，用于对HTTP请求的body进行streaming
      #
      class StreamReader
        def initialize(block)
          @block = block
          @chunks = []
        end

        def read(size)
          return @chunks.shift unless @chunks.empty?

          @block.call(self) if @chunks.empty?
          @chunks.shift
        end

        def write(chunk)
          @chunks << chunk
        end

        alias << write

        def closed?
          false
        end

        def close
          true
        end

        def close!
          close
        end
      end

      class << self

        include Logging

        # 获取请求的URL，根据操作是否指定bucket和object，URL可能不同
        def get_request_url(bucket, object)
          url = ""
          url += "#{bucket}." if bucket
          url += Config.get(:endpoint)
          url += "/#{object}" if object

          url
        end

        # 获取请求的资源路径
        def get_resource_path(bucket, object)
          if bucket
            res = "/#{bucket}/"
            res += "#{object}" if object
            res
          end
        end

        # Handle Net::HTTPRespoonse
        def handle_response(r, &block)
          # read all body on error
          if r.code.to_i >= 300
            r.read_body
          else
          # streaming read body on success
            r.read_body do |chunk|
              decoded_chunk =
                RestClient::Request.decode(r['content-encoding'], chunk)
              block.call(decoded_chunk)
            end
          end
        end

        # 进行RESTful HTTP请求
        # [verb] HTTP动作: GET/PUT/POST/DELETE/HEAD
        # [resources] OSS相关的资源:
        #     [:bucket] bucket名字
        #     [:object] object名字
        #     [:sub_res] 子资源
        # [http_options] HTTP相关资源：
        #     [:headers] HTTP头
        #     [:body] HTTP body
        #     [:query] HTTP url参数
        def do_request(verb, resources = {}, http_options = {}, &block)
          bucket = resources[:bucket]
          object = resources[:object]
          sub_res = resources[:sub_res]

          headers = http_options[:headers] || {}
          headers['Date'] = Util.get_date
          headers['Content-Type'] = 'application/octet-stream'

          res = {
            :path => get_resource_path(bucket, object),
            :sub_res => sub_res,
          }
          signature = Util.get_signature(Config.get(:access_key), verb, headers, res)
          auth = "OSS #{Config.get(:access_id)}:#{signature}"
          headers['Authorization']  = auth

          logger.debug("Send HTTP request, verb: #{verb}, resources: #{resources}, http options: #{http_options}")

          # from rest-client:
          # "Due to unfortunate choices in the original API, the params
          # used to populate the query string are actually taken out of
          # the headers hash."
          headers[:params] = (sub_res || {}).merge(http_options[:query] || {})

          block_response = lambda {|r| handle_response(r, &block) } if block
          r = RestClient::Request.execute(
            :method => verb,
            :url => get_request_url(bucket, object),
            :headers => headers,
            :payload => http_options[:body],
            :block_response =>  block_response
          ) do |response, request, result, &blk|

            if response.code >= 400
              e = ServerError.new(response.code, response.body)
              logger.error(e.to_s)
              raise e
            else
              response.return!(request, result, &blk)
            end
          end

          # If streaming read_body is used, we need to create the
          # RestClient::Response ourselves
          unless r.is_a?(RestClient::Response)
            if r.code.to_i >= 300
              r = RestClient::Response.create(
                RestClient::Request.decode(r['content-encoding'], r.body),
                r, nil, nil)
              e = ServerError.new(r.code, r.body)
              logger.error(e.to_s)
              raise e
            end
            r = RestClient::Response.create(nil, r, nil, nil)
            r.return!
          end

          logger.debug("Received HTTP response, code: #{r.code}, headers: #{r.headers}, body: #{r.body}")

          r.body
        end

      end # self

    end # HTTP

  end # OSS
end # Aliyun
