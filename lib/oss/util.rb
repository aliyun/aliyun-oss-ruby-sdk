# -*- encoding: utf-8 -*-

require 'time'
require 'base64'
require 'openssl'
require 'net/http'

class String
  def to_bool
    return true if self =~ /^true$/i
    false
  end
end

class Array
  def symbolize_keys!
    self.each{ |v| v.symbolize_keys! if v.is_a?(Hash) or v.is_a?(Array) }
  end
end

class Hash
  def symbolize_keys!
    self.keys.each{ |k| self[k.to_sym] = self.delete(k) }
    self.values.each{ |v| v.symbolize_keys! if v.is_a?(Hash) or v.is_a?(Array) }
  end
end

module Aliyun
  module OSS
    ##
    # SDK的一些辅助函数：按格式输出日期，计算签名等
    #
    module Util

      # OSS请求自定义的HTTP header的前缀
      HEADER_PREFIX = "x-oss-"

      class << self

        include Logging

        # 获取当前时间，按Fri, 30 Oct 2015 07:21:00 GMT的格式
        def get_date
          t = Time.now.utc.rfc822
          t.sub("-0000", "GMT")
        end

        # 计算请求签名
        def get_signature(key, verb, headers, resources)
          logger.debug("Sign, headers: #{headers}, resources: #{resources}")

          content_md5 = headers['Content-MD5'] || ""
          content_type = headers['Content-Type'] || ""
          date = headers['Date']

          cano_headers = headers.select do |k, v|
            k.start_with?(HEADER_PREFIX)
          end.map do |k, v|
            [k.downcase.strip, v.strip]
          end.sort.map do |k, v|
            [k, v].join(":") + "\n"
          end.join

          cano_res = resources[:path] || "/"
          sub_res = (resources[:sub_res] || {}).sort.map do |k, v|
            v ? [k, v].join("=") : k
          end.join("&")
          cano_res += "?#{sub_res}" unless sub_res.empty?

          string_to_sign =
            "#{verb}\n#{content_md5}\n#{content_type}\n#{date}\n" +
            "#{cano_headers}#{cano_res}"

          logger.debug("String to sign: #{string_to_sign}")

          Base64.encode64(
            OpenSSL::HMAC.digest('sha1', key, string_to_sign))
        end

        # 计算body的md5
        def get_content_md5(content)
          Base64.encode64(OpenSSL::Digest::MD5.digest(content))
        end

      end # self
    end # Util
  end # OSS
end # Aliyun
