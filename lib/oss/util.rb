require 'time'
require 'base64'
require 'openssl'
require 'net/http'

module Aliyun
  module OSS
    module Util
      HEADER_PREFIX = "x-oss-"

      class << self

        def get_date
          t = Time.now.utc.rfc822
          t.sub("-0000", "GMT")
        end

        def get_signature(key, verb, headers, body, resources)
          content_md5 = headers['Content-MD5'] || ""
          content_type = headers['Content-Type'] || ""
          date = headers['Date']

          cano_headers = headers.select do |k, v|
            k.start_with?(HEADER_PREFIX)
          end.map do |k, v|
            [k.downcase.strip, v.strip]
          end.sort.map do |k, v|
            [k, v].join(":")
          end.join("\n")

          cano_res = resources[:res] || "/"
          sub_res = (resources[:sub] || {}).sort.map do |k, v|
            v ? [k, v].join("=") : k
          end.join("&")
          cano_res += "?#{sub_res}" unless sub_res.empty?

          string_to_sign =
            "#{verb}\n#{content_md5}\n#{content_type}\n#{date}\n" +
            "#{cano_headers}#{cano_res}"

          Base64.encode64(
            OpenSSL::HMAC.digest('sha1', key, string_to_sign))
        end

        def get_content_md5(content)
          Base64.encode64(OpenSSL::Digest::MD5.digest(content))
        end
      end # self
    end # Util
  end # OSS
end # Aliyun
