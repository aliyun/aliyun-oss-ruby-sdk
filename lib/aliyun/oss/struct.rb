# -*- encoding: utf-8 -*-

module Aliyun
  module OSS

    ##
    # Access Control List, it controls how the bucket/object can be
    # accessed.
    # * public-read-write: allow access(read&write) anonymously
    # * public-read: allow read anonymously
    # * private: access must be signatured
    #
    module ACL
      PUBLIC_READ_WRITE = "public-read-write"
      PUBLIC_READ = "public-read"
      PRIVATE = "private"
    end # ACL

    ##
    # A OSS object may carry some metas(String key-value pairs) with
    # it. MetaDirective specifies what to do with the metas in the
    # copy process.
    # * COPY: metas are copied from the source object to the dest
    #   object
    # * REPLACE: source object's metas are NOT copied, use user
    #   provided metas for the dest object
    #
    module MetaDirective
      COPY = "COPY"
      REPLACE = "REPLACE"
    end # MetaDirective

    ##
    # The object key may contains unicode charactors which cannot be
    # encoded in the request/response body(XML). KeyEncoding specifies
    # the encoding type for the object key.
    # * url: the object key is url-encoded
    # @note url-encoding is the only supported KeyEncoding type
    #
    module KeyEncoding
      URL = "url"

      @@all = [URL]

      def self.include?(enc)
        all.include?(enc)
      end

      def self.all
        @@all
      end
    end # KeyEncoding

    ##
    # Bucket Logging setting. See: {http://help.aliyun.com/document_detail/oss/product-documentation/function/logging.html OSS Bucket logging}
    # Attributes:
    # * enable [Boolean] whether to enable bucket logging
    # * target_bucket [String] the target bucket to store access logs
    # * target_prefix [String] the target object prefix to store access logs
    # @example Enable bucket logging
    #  bucket.logging = BucketLogging.new(
    #    :enable => true, :target_bucket => 'log_bucket', :target_prefix => 'my-log')
    # @example Disable bucket logging
    #  bucket.logging = BucketLogging.new(:enable => false)
    class BucketLogging < Common::Struct::Base
      attrs :enable, :target_bucket, :target_prefix

      def enabled?
        enable == true
      end
    end

    ##
    # Bucket website setting. See: {http://help.aliyun.com/document_detail/oss/product-documentation/function/host-static-website.html OSS Website hosting}
    # Attributes:
    # * enable [Boolean] whether to enable website hosting for the bucket
    # * index [String] the index object as the index page for the website
    # * error [String] the error object as the error page for the website
    class BucketWebsite < Common::Struct::Base
      attrs :enable, :index, :error

      def enabled?
        enable == true
      end
    end

    ##
    # Bucket referer setting. See: {http://help.aliyun.com/document_detail/oss/product-documentation/function/referer-white-list.html OSS Website hosting}
    # Attributes:
    # * allow_empty [Boolean] whether to allow requests with empty "Referer"
    # * whitelist [Array<String>] the allowed origins for requests
    class BucketReferer < Common::Struct::Base
      attrs :allow_empty, :whitelist

      def allow_empty?
        allow_empty == true
      end
    end

    ##
    # LifeCycle rule for bucket. See: {http://help.aliyun.com/document_detail/oss/product-documentation/function/lifecycle.html OSS Bucket LifeCycle}
    # Attributes:
    # * id [String] the unique id of a rule
    # * enabled [Boolean] whether to enable this rule
    # * prefix [String] the prefix objects to apply this rule
    # * expiry [Date] or [Fixnum] the expire time of objects
    #   * if expiry is a Date, it specifies the absolute date to
    #     expire objects
    #   * if expiry is a Fixnum, it specifies the relative date to
    #     expire objects: how many days after the object's last
    #     modification time to expire the object
    # @example Specify expiry as Date
    #   LifeCycleRule.new(
    #     :id => 'rule1',
    #     :enabled => true,
    #     :prefix => 'foo/',
    #     :expiry => Date.new(2016, 1, 1))
    # @example Specify expiry as days
    #   LifeCycleRule.new(
    #     :id => 'rule1',
    #     :enabled => true,
    #     :prefix => 'foo/',
    #     :expiry => 15)
    # @note the expiry date is treated as UTC time
    class LifeCycleRule < Common::Struct::Base

      attrs :id, :enable, :prefix, :expiry

      def enabled?
        enable == true
      end
    end # LifeCycleRule

    ##
    # CORS rule for bucket. See: {http://help.aliyun.com/document_detail/oss/product-documentation/function/referer-white-list.html OSS CORS}
    # Attributes:
    # * allowed_origins [Array<String>] the allowed origins
    # * allowed_methods [Array<String>] the allowed methods
    # * allowed_headers [Array<String>] the allowed headers
    # * expose_headers [Array<String>] the expose headers
    # * max_age_seconds [Integer] the max age seconds
    class CORSRule < Common::Struct::Base

      attrs :allowed_origins, :allowed_methods, :allowed_headers,
            :expose_headers, :max_age_seconds

    end # CORSRule

  end # OSS
end # Aliyun
