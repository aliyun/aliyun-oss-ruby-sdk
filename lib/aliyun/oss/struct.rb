# -*- encoding: utf-8 -*-

require 'base64'
require 'json'
require 'uri'

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

    # Bucket Info. See: {https://help.aliyun.com/document_detail/31968.html}
    # Attributes:
    # * name [String] the name of the bucket
    # * creation_date [String] the date when the bucket is created
    # * storage_class [String] the storage type of the bucket
    # @example
    #  Standard/IA/Archive
    # * extranet_endpoint [String] the extranet endpoint to visit the bucket
    # * intranet_endpoint [String] the intranet endpoint to visit the bucket
    # * location [String] the location of the bucket
    # * owner_display_name [String] the user name of the bucket owner
    # currently, owner_display name is the same as owner_id
    # * owner_id [String] the user id of the bucket owner
    # * grant [String] the ACL privilege of the bucket
    # @example
    # private/public-read/public-read-write
    class BucketInfo < Common::Struct::Base
      attrs :name, :creation_date, :storage_class,
            :extranet_endpoint, :intranet_endpoint,
            :location, :owner_display_name, :owner_id, :grant
    end

    # Bucket Stat
    # Attributes:
    # * storage [Integer] the total size of this bucket, unit: Byte
    # * object_count [Integer] the toal num of objects in this bucket
    # * multipart_upload_count [Integer] the total num of mutilpart_uploaded objects in this bucket
    class BucketStat < Common::Struct::Base
      attrs :storage, :object_count, :multipart_upload_count
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
    # * is_created_before_date [Boolean] the date type of expiry when expiry is a Date
    #   * if is_created_before_date is true,
    #       the type of expiry is created_before_date type
    #   * if is_created_before_date is false,
    #       the type of expiry is date type
    # * the difference between date type and created_before_date type:
    #   * if expiry is date type, matched files will be deleted after the date no matter what.
    #           date type is not suggested to use
    #   * if expiry is created_before_date type,
    #        matched files'll be deleted if their last modified time earlier than created_before_date
    # * expiry [Date] or [Fixnum] the expire time of objects
    #   * if expiry is a Date,
    #       if is_created_before_date is false,
    #            it specifies the absolute date to expire objects
    #       if is_created_before_date is true,
    #            it specifies to expire objects whose last modification
    #            time is earlier than the date
    #   * if expiry is a Fixnum, it specifies the relative date to
    #     expire objects: how many days after the object's last
    #     modification time to expire the object
    # @example Specify expiry as Date
    #   LifeCycleRule.new(
    #     :id => 'rule1',
    #     :enabled => true,
    #     :prefix => 'foo/',
    #     :expiry => Date.new(2016, 1, 1))
    # @example Specify expiry as CreatedBeforeDate
    #   LifeCycleRule.new(
    #     :id => 'rule1',
    #     :enabled => true,
    #     :prefix => 'foo/',
    #     :is_created_before_date => true,
    #     :expiry => Date.new(2016, 1, 1))
    # @example Specify expiry as days
    #   LifeCycleRule.new(
    #     :id => 'rule1',
    #     :enabled => true,
    #     :prefix => 'foo/',
    #     :expiry => 15)
    # @note the expiry date is treated as UTC time
    # * abort_multipart_upload [Date] or [Fixnum]
    # the expire time of unfinished multipart-uploaded parts
    #   * if abort_multipart_upload is a Date,
    #     it specifies the absolute date to expire parts
    #   * if abort_multipart_upload is a Fixnum,
    #     it specifies the relative date to
    #     expire parts: how many days after the part's last
    #     modification time to expire the part
    # @example Specify abort_multipart_upload as Date
    #   LifeCycleRule.new(
    #     :id => 'rule1',
    #     :enabled => true,
    #     :prefix => 'foo/',
    #     :abort_multipart_upload => Date.new(2016, 1, 1))
    # @example Specify abort_multipart_upload as days
    #   LifeCycleRule.new(
    #     :id => 'rule1',
    #     :enabled => true,
    #     :prefix => 'foo/',
    #     :abort_multipart_upload => 15)
    # @note the abort_multipart_upload date is treated as UTC time
    class LifeCycleRule < Common::Struct::Base

      attrs :id, :enable, :prefix, :expiry,
            :is_created_before_date,
            :abort_multipart_upload

      def is_created_before_date?
        is_created_before_date == true
      end

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

    ##
    # Callback represents a HTTP call made by OSS to user's
    # application server after an event happens, such as an object is
    # successfully uploaded to OSS. See: {https://help.aliyun.com/document_detail/oss/api-reference/object/Callback.html}
    # Attributes:
    # * url [String] the URL *WITHOUT* the query string
    # * query [Hash] the query to generate query string
    # * body [String] the body of the request
    # * content_type [String] the Content-Type of the request
    # * host [String] the Host in HTTP header for this request
    class Callback < Common::Struct::Base

      attrs :url, :query, :body, :content_type, :host

      include Common::Logging

      def serialize
        query_string = (query || {}).map { |k, v|
          [CGI.escape(k.to_s), CGI.escape(v.to_s)].join('=') }.join('&')

        cb = {
          'callbackUrl' => "#{normalize_url(url)}?#{query_string}",
          'callbackBody' => body,
          'callbackBodyType' => content_type || default_content_type
        }
        cb['callbackHost'] = host if host

        logger.debug("Callback json: #{cb}")

        Base64.strict_encode64(cb.to_json)
      end

      private
      def normalize_url(url)
        uri = URI.parse(url)
        uri = URI.parse("http://#{url}") unless uri.scheme

        if uri.scheme != 'http' and uri.scheme != 'https'
          fail ClientError, "Only HTTP and HTTPS endpoint are accepted."
        end

        unless uri.query.nil?
          fail ClientError, "Query parameters should not appear in URL."
        end

        uri.to_s
      end

      def default_content_type
        "application/x-www-form-urlencoded"
      end

    end # Callback

  end # OSS
end # Aliyun
