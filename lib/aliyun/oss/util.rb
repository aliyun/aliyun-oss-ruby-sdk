# -*- encoding: utf-8 -*-

require 'time'
require 'base64'
require 'openssl'

module Aliyun
  module OSS
    ##
    # Util functions to help generate formatted Date, signatures,
    # etc.
    #
    module Util

      # Prefix for OSS specific HTTP headers
      HEADER_PREFIX = "x-oss-"

      class << self

        include Logging

        # Calculate request signatures
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

        # Calculate content md5
        def get_content_md5(content)
          Base64.encode64(OpenSSL::Digest::MD5.digest(content))
        end

      end # self
    end # Util
  end # OSS
end # Aliyun

# Monkey patch to support #to_bool
class String
  def to_bool
    return true if self =~ /^true$/i
    false
  end
end

# Monkey patch to support #symbolize_keys!
class Array
  def symbolize_keys!
    self.each{ |v| v.symbolize_keys! if v.is_a?(Hash) or v.is_a?(Array) }
  end
end

# Monkey patch to support #symbolize_keys!
class Hash
  def symbolize_keys!
    self.keys.each{ |k| self[k.to_sym] = self.delete(k) }
    self.values.each{ |v| v.symbolize_keys! if v.is_a?(Hash) or v.is_a?(Array) }
  end
end
