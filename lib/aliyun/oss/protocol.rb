# -*- encoding: utf-8 -*-

require 'rest-client'
require 'nokogiri'
require 'time'

module Aliyun
  module OSS

    ##
    # Protocol implement the OSS Open API which is low-level. User
    # should refer to {OSS::Client} for normal use.
    #
    class Protocol

      STREAM_CHUNK_SIZE = 16 * 1024

      include Logging

      def initialize(config)
        @http = HTTP.new(config)
      end

      # List all the buckets.
      # @param opts [Hash] options
      # @option opts [String] :prefix return only those buckets
      #  prefixed with it if specified
      # @option opts [String] :marker return buckets after where it
      #  indicates (exclusively). All buckets are sorted by name
      #  alphabetically
      # @option opts [Integer] :limit return only the first N
      #  buckets if specified
      # @return [Array<Bucket>, Hash] the returned buckets and a
      #  hash including the next tokens, which includes:
      #  * :prefix [String] the prefix used
      #  * :delimiter [String] the delimiter used
      #  * :marker [String] the marker used
      #  * :limit [Integer] the limit used
      #  * :next_marker [String] marker to continue list buckets
      #  * :truncated [Boolean] whether there are more buckets to
      #    be returned
      def list_buckets(opts = {})
        logger.info("Begin list buckets, options: #{opts}")

        params = {
          'prefix' => opts[:prefix],
          'marker' => opts[:marker],
          'max-keys' => opts[:limit]
        }.select {|_, v| v != nil}

        _, body = @http.get( {}, {:query => params})
        doc = parse_xml(body)

        buckets = doc.css("Buckets Bucket").map do |node|
          Bucket.new(
            {
              :name => get_node_text(node, "Name"),
              :location => get_node_text(node, "Location"),
              :creation_time =>
                get_node_text(node, "CreationDate") {|t| Time.parse(t)}
            }, self
          )
        end

        more = Hash[
          {
            :prefix => 'Prefix',
            :limit => 'MaxKeys',
            :marker => 'Marker',
            :next_marker => 'NextMarker',
            :truncated => 'IsTruncated'
          }.map do |k, v|
            [k, get_node_text(doc.root, v)]
          end].select {|k, v| v != nil}

        more.update(
          :limit => wrap(more[:limit]) {|x| x.to_i},
          :truncated => wrap(more[:truncated]) {|x| x.to_bool}
        )

        logger.info("Done list buckets, buckets: #{buckets}, more: #{more}")

        [buckets, more.select{ |_, v| v != nil }]
      end

      # Create a bucket
      # @param name [String] the bucket name
      # @param opts [Hash] options
      # @option opts [String] :location the region where the bucket
      #  is located
      # @example
      #   oss-cn-hangzhou
      def create_bucket(name, opts = {})
        logger.info("Begin create bucket, name: #{name}, opts: #{opts}")

        location = opts[:location]
        body = nil
        if location
          builder = Nokogiri::XML::Builder.new do |xml|
            xml.CreateBucketConfiguration {
              xml.LocationConstraint location
            }
          end
          body = builder.to_xml
        end

        @http.put({:bucket => name}, {:body => body})

        logger.info("Done create bucket")
      end

      # Update bucket acl
      # @param name [String] the bucket name
      # @param acl [String] the bucket acl
      # @see OSS::ACL
      def update_bucket_acl(name, acl)
        logger.info("Begin update bucket acl, name: #{name}, acl: #{acl}")

        sub_res = {'acl' => nil}
        headers = {'x-oss-acl' => acl}
        @http.put(
          {:bucket => name, :sub_res => sub_res},
          {:headers => headers, :body => nil})

        logger.info("Done update bucket acl")
      end

      # Get bucket acl
      # @param name [String] the bucket name
      # @return [String] the acl of this bucket
      def get_bucket_acl(name)
        logger.info("Begin get bucket acl, name: #{name}")

        sub_res = {'acl' => nil}
        _, body = @http.get({:bucket => name, :sub_res => sub_res})

        doc = parse_xml(body)
        acl = get_node_text(doc.at_css("AccessControlList"), 'Grant')
        logger.info("Done get bucket acl")

        acl
      end

      # Update bucket logging settings
      # @param name [String] the bucket name
      # @param opts [Hash] logging options
      # @option opts [Boolean] :enable whether to enable logging
      # @option opts [String] :target_bucket the target bucket to
      #  store logging objects
      # @option opts [String] :prefix only turn on logging for those
      #  objects prefixed with it if specified
      def update_bucket_logging(name, opts)
        logger.info("Begin update bucket logging, name: #{name}, options: #{opts}")

        raise ClientError.new("Must specify :enabled when update bucket logging.") \
                             unless opts.has_key?(:enable)
        raise ClientError.new("Must specify target bucket when enabling bucket logging.") \
                             if opts[:enable] and not opts.has_key?(:target_bucket)
        raise ClientError.new("Unexpected extra options when update bucket logging.") \
                             if (opts.size > 1 and not opts[:enable])

        sub_res = {'logging' => nil}
        body = Nokogiri::XML::Builder.new do |xml|
          xml.BucketLoggingStatus {
            if opts[:enable]
              xml.LoggingEnabled {
                xml.TargetBucket opts[:target_bucket]
                xml.TargetPrefix opts[:prefix] if opts[:prefix]
              }
            end
          }
        end.to_xml

        @http.put(
          {:bucket => name, :sub_res => sub_res},
          {:body => body})

        logger.info("Done update bucket logging")
      end

      # Get bucket logging settings
      # @param name [String] the bucket name
      # @return [Hash] logging options of this bucket
      # @see #set_bucket_logging
      def get_bucket_logging(name)
        logger.info("Begin get bucket logging, name: #{name}")

        sub_res = {'logging' => nil}
        _, body = @http.get({:bucket => name, :sub_res => sub_res})

        doc = parse_xml(body)
        opts = {:enable => false}

        logging_node = doc.at_css("LoggingEnabled")
        opts.update(
          :target_bucket => get_node_text(logging_node, 'TargetBucket'),
          :prefix => get_node_text(logging_node, 'TargetPrefix')
        )
        opts[:enable] = true if opts[:target_bucket]

        logger.info("Done get bucket logging")

        opts.select {|_, v| v != nil}
      end

      # Delete bucket logging settings, a.k.a. disable bucket logging
      # @param name [String] the bucket name
      def delete_bucket_logging(name)
        logger.info("Begin delete bucket logging, name: #{name}")

        sub_res = {'logging' => nil}
        @http.delete({:bucket => name, :sub_res => sub_res})

        logger.info("Done delete bucket logging")
      end

      # Update bucket website settings
      # @param name [String] the bucket name
      # @param opts [Hash] the bucket website options
      # @option opts [String] :index the object name to serve as the
      #  index page of website
      # @option opts [String] :error the object name to serve as the
      #  error page of website
      def update_bucket_website(name, opts)
        logger.info("Begin update bucket website, name: #{name}, options: #{opts}")

        raise ClientError.new("Must specify :index to update bucket website") \
                             unless opts.has_key?(:index)

        sub_res = {'website' => nil}
        body = Nokogiri::XML::Builder.new do |xml|
          xml.WebsiteConfiguration {
            xml.IndexDocument {
              xml.Suffix opts[:index]
            }
            if opts[:error]
              xml.ErrorDocument {
                xml.Key opts[:error]
              }
            end
          }
        end.to_xml

        @http.put(
          {:bucket => name, :sub_res => sub_res},
          {:body => body})

        logger.info("Done update bucket website")
      end

      # Get bucket website settings
      # @param name [String] the bucket name
      # @return [Hash] the bucket website options
      # @see set_bucket_website
      def get_bucket_website(name)
        logger.info("Begin get bucket website, name: #{name}")

        sub_res = {'website' => nil}
        _, body = @http.get({:bucket => name, :sub_res => sub_res})

        opts = {}
        doc = parse_xml(body)
        opts.update(
          :index => get_node_text(doc.at_css('IndexDocument'), 'Suffix'),
          :error => get_node_text(doc.at_css('ErrorDocument'), 'Key')
        )

        logger.info("Done get bucket website")

        opts.select {|_, v| v != nil}
      end

      # Delete bucket website settings
      # @param name [String] the bucket name
      def delete_bucket_website(name)
        logger.info("Begin delete bucket website, name: #{name}")

        sub_res = {'website' => nil}
        @http.delete({:bucket => name, :sub_res => sub_res})

        logger.info("Done delete bucket website")
      end

      # Update bucket referer
      # @param name [String] the bucket name
      # @param opts [Hash] the bucket referer options
      # @option opts [Boolean] :allow_empty whether to allow empty
      #  referer
      # @option opts [Array<String>] :referers the referer white
      #  list to allow access to this bucket
      def update_bucket_referer(name, opts)
        logger.info("Begin update bucket referer, name: #{name}, options: #{opts}")

        raise ClientError.new("Must specify :allow_empty to update bucket referer.") \
                             unless opts.has_key?(:allow_empty)

        sub_res = {'referer' => nil}
        body = Nokogiri::XML::Builder.new do |xml|
          xml.RefererConfiguration {
            xml.AllowEmptyReferer opts[:allow_empty]
            xml.RefererList {
              (opts[:referers] or []).each do |r|
                xml.Referer r
              end
            }
          }
        end.to_xml

        @http.put(
          {:bucket => name, :sub_res => sub_res},
          {:body => body})

        logger.info("Done update bucket referer")
      end

      # Get bucket referer
      # @param name [String] the bucket name
      # @return [Hash] the bucket referer options
      # @see #set_bucket_referer
      def get_bucket_referer(name)
        logger.info("Begin get bucket referer, name: #{name}")

        sub_res = {'referer' => nil}
        _, body = @http.get({:bucket => name, :sub_res => sub_res})

        doc = parse_xml(body)
        opts = {
          :allow_empty => get_node_text(doc.root, 'AllowEmptyReferer') {|x| x.to_bool},
          :referers => doc.css("RefererList Referer").map {|n| n.text}
        }

        logger.info("Done get bucket referer")

        opts.select {|_, v| v != nil}
      end

      # Update bucket lifecycle settings
      # @param name [String] the bucket name
      # @param rules [Array<OSS::LifeCycleRule>] the
      #  lifecycle rules
      # @see OSS::LifeCycleRule
      def update_bucket_lifecycle(name, rules)
        logger.info("Begin update bucket lifecycle, name: #{name}, rules: " \
                     "#{rules.map {|r| r.to_s}}")

        sub_res = {'lifecycle' => nil}
        body = Nokogiri::XML::Builder.new do |xml|
          xml.LifecycleConfiguration {
            rules.each do |r|
              xml.Rule {
                xml.ID r.id if r.id
                xml.Status r.enabled ? 'Enabled' : 'Disabled'

                xml.Prefix r.prefix
                xml.Expiration {
                  if r.expiry.is_a?(Date)
                    xml.Date Time.utc(r.expiry.year, r.expiry.month, r.expiry.day)
                              .iso8601.sub('Z', '.000Z')
                  elsif r.expiry.is_a?(Fixnum)
                    xml.Days r.expiry
                  else
                    raise ClientError.new("Expiry must be a Date or Fixnum.")
                  end
                }
              }
            end
          }
        end.to_xml

        @http.put(
          {:bucket => name, :sub_res => sub_res},
          {:body => body})

        logger.info("Done update bucket lifecycle")
      end

      # Get bucket lifecycle settings
      # @param name [String] the bucket name
      # @return [Array<OSS::LifeCycleRule>] the
      #  lifecycle rules. See {OSS::LifeCycleRule}
      def get_bucket_lifecycle(name)
        logger.info("Begin get bucket lifecycle, name: #{name}")

        sub_res = {'lifecycle' => nil}
        _, body = @http.get({:bucket => name, :sub_res => sub_res})

        doc = parse_xml(body)
        rules = doc.css("Rule").map do |n|
          days = n.at_css("Expiration Days")
          date = n.at_css("Expiration Date")

          raise Client.new("We can only have one of Date and Days for expiry.") \
                          if (days and date) or (not days and not date)

          LifeCycleRule.new(
            :id => get_node_text(n, 'ID'),
            :prefix => get_node_text(n, 'Prefix'),
            :enabled => get_node_text(n, 'Status') {|x| x == 'Enabled'},
            :expiry => days ? days.text.to_i : Date.parse(date.text)
          )
        end
        logger.info("Done get bucket lifecycle")

        rules
      end

      # Delete *all* lifecycle rules on the bucket
      # @note this will delete all lifecycle rules
      # @param name [String] the bucket name
      def delete_bucket_lifecycle(name)
        logger.info("Begin delete bucket lifecycle, name: #{name}")

        sub_res = {'lifecycle' => nil}
        @http.delete({:bucket => name, :sub_res => sub_res})

        logger.info("Done delete bucket lifecycle")
      end

      # Set bucket CORS(Cross-Origin Resource Sharing) rules
      # @param name [String] the bucket name
      # @param rules [Array<OSS::CORSRule] the CORS
      #  rules
      # @see OSS::CORSRule
      def set_bucket_cors(name, rules)
        logger.info("Begin set bucket cors, bucket: #{name}, rules: " \
                     "#{rules.map {|r| r.to_s}.join(';')}")

        sub_res = {'cors' => nil}
        body = Nokogiri::XML::Builder.new do |xml|
          xml.CORSConfiguration {
            rules.each do |r|
              xml.CORSRule {
                r.allowed_origins.each do |x|
                  xml.AllowedOrigin x
                end
                r.allowed_methods.each do |x|
                  xml.AllowedMethod x
                end
                r.allowed_headers.each do |x|
                  xml.AllowedHeader x
                end
                r.expose_headers.each do |x|
                  xml.ExposeHeader x
                end
                xml.MaxAgeSeconds r.max_age_seconds if r.max_age_seconds
              }
            end
          }
        end.to_xml

        @http.put(
          {:bucket => name, :sub_res => sub_res},
          {:body => body})

        logger.info("Done delete bucket lifecycle")
      end

      # Get bucket CORS rules
      # @param name [String] the bucket name
      # @return [Array<OSS::CORSRule] the CORS rules
      def get_bucket_cors(name)
        logger.info("Begin get bucket cors, bucket: #{name}")

        sub_res = {'cors' => nil}
        _, body = @http.get({:bucket => name, :sub_res => sub_res})

        doc = parse_xml(body)
        rules = []

        doc.css("CORSRule").map do |n|
          allowed_origins = n.css("AllowedOrigin").map {|x| x.text}
          allowed_methods = n.css("AllowedMethod").map {|x| x.text}
          allowed_headers = n.css("AllowedHeader").map {|x| x.text}
          expose_headers = n.css("ExposeHeader").map {|x| x.text}
          max_age_seconds = get_node_text(n, 'MaxAgeSeconds') {|x| x.to_i}

          rules << CORSRule.new(
            :allowed_origins => allowed_origins,
            :allowed_methods => allowed_methods,
            :allowed_headers => allowed_headers,
            :expose_headers => expose_headers,
            :max_age_seconds => max_age_seconds)
        end

        logger.info("Done get bucket cors")

        rules
      end

      # Delete all bucket CORS rules
      # @note this will delete all CORS rules of this bucket
      # @param name [String] the bucket name
      def delete_bucket_cors(name)
        logger.info("Begin delete bucket cors, bucket: #{name}")

        sub_res = {'cors' => nil}

        @http.delete({:bucket => name, :sub_res => sub_res})

        logger.info("Done delete bucket cors")
      end

      # Delete a bucket
      # @param name [String] the bucket name
      # @note it will fails if the bucket is not empty (it contains
      #  objects)
      def delete_bucket(name)
        logger.info("Begin delete bucket: #{name}")

        @http.delete({:bucket => name})

        logger.info("Done delete bucket")
      end

      # Put an object to the specified bucket, a block is required
      # to provide the object data.
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param opts [Hash] Options
      # @option opts [String] :content_type the HTTP Content-Type
      #  for the file, if not specified client will try to determine
      #  the type itself and fall back to HTTP::DEFAULT_CONTENT_TYPE
      #  if it fails to do so
      # @option opts [Hash<Symbol, String>] :metas key-value pairs
      #  that serve as the object meta which will be stored together
      #  with the object
      # @yield [HTTP::StreamWriter] a stream writer is
      #  yielded to the caller to which it can write chunks of data
      #  streamingly
      # @example
      #   chunk = get_chunk
      #   put_object('bucket', 'object') { |sw| sw.write(chunk) }
      def put_object(bucket_name, object_name, opts = {}, &block)
        logger.debug("Begin put object, bucket: #{bucket_name}, object: "\
                     "#{object_name}, options: #{opts}")

        headers = {'Content-Type' => opts[:content_type]}
        (opts[:metas] || {}).each{ |k, v| headers["x-oss-meta-#{k.to_s}"] = v.to_s }

        @http.put(
          {:bucket => bucket_name, :object => object_name},
          {:headers => headers, :body => HTTP::StreamPayload.new(&block)})

        logger.debug('Done put object')
      end

      # Append to an object of a bucket. Create an "Appendable
      # Object" if the object does not exist. A block is required to
      # provide the appending data.
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param position [Integer] the position to append
      # @param opts [Hash] Options
      # @option opts [String] :content_type the HTTP Content-Type
      #  for the file, if not specified client will try to determine
      #  the type itself and fall back to HTTP::DEFAULT_CONTENT_TYPE
      #  if it fails to do so
      # @option opts [Hash<Symbol, String>] :metas key-value pairs
      #  that serve as the object meta which will be stored together
      #  with the object
      # @return [Integer] next position to append
      # @yield [HTTP::StreamWriter] a stream writer is
      #  yielded to the caller to which it can write chunks of data
      #  streamingly
      # @note
      #   1. Can not append to a "Normal Object"
      #   2. The position must equal to the object's size before append
      #   3. The :content_type is only used when the object is created
      def append_object(bucket_name, object_name, position, opts = {}, &block)
        logger.debug("Begin append object, bucket: #{bucket_name}, object: " \
                      "#{object_name}, position: #{position}, options: #{opts}")

        sub_res = {'append' => nil, 'position' => position}
        headers = {'Content-Type' => opts[:content_type]}
        (opts[:metas] || {}).each{ |k, v| headers["x-oss-meta-#{k.to_s}"] = v.to_s }

        h, _ = @http.post(
             {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
             {:headers => headers, :body => HTTP::StreamPayload.new(&block)})

        logger.debug('Done append object')

        wrap(h[:x_oss_next_append_position]){ |x| x.to_i } || -1
      end

      # List objects in a bucket.
      # @param bucket_name [String] the bucket name
      # @param opts [Hash] options
      # @option opts [String] :prefix return only those buckets
      #  prefixed with it if specified
      # @option opts [String] :marker return buckets after where it
      #  indicates (exclusively). All buckets are sorted by name
      #  alphabetically
      # @option opts [Integer] :limit return only the first N
      #  buckets if specified
      # @option opts [String] :delimiter the delimiter to get common
      #  prefixes of all objects
      # @option opts [String] :encoding the encoding of object key
      #  in the response body. Only {OSS::KeyEncoding::URL} is
      #  supported now.
      # @example
      #  Assume we have the following objects:
      #     /foo/bar/obj1
      #     /foo/bar/obj2
      #     ...
      #     /foo/bar/obj9999999
      #     /foo/xxx/
      #  use 'foo/' as the prefix, '/' as the delimiter, the common
      #  prefixes we get are: '/foo/bar/', '/foo/xxx/'. They are
      #  coincidentally the sub-directories under '/foo/'. Using
      #  delimiter we avoid list all the objects whose number may be
      #  large.
      # @return [Array<Objects>, Hash] the returned object and a
      #  hash including the next tokens, which includes:
      #  * :common_prefixes [String] the common prefixes returned
      #  * :prefix [String] the prefix used
      #  * :delimiter [String] the delimiter used
      #  * :marker [String] the marker used
      #  * :limit [Integer] the limit used
      #  * :next_marker [String] marker to continue list objects
      #  * :truncated [Boolean] whether there are more objects to
      #    be returned
      def list_objects(bucket_name, opts = {})
        logger.debug("Begin list object, bucket: #{bucket_name}, options: #{opts}")

        params = {
          'prefix' => opts[:prefix],
          'delimiter' => opts[:delimiter],
          'marker' => opts[:marker],
          'max-keys' => opts[:limit],
          'encoding-type' => opts[:encoding]
        }.select {|_, v| v != nil}

        _, body = @http.get({:bucket => bucket_name}, {:query => params})

        doc = parse_xml(body)

        encoding = get_node_text(doc.root, 'EncodingType')

        objects = doc.css("Contents").map do |node|
          Object.new(
            :key => get_node_text(node, "Key") {|x| decode_key(x, encoding)},
            :type => get_node_text(node, "Type"),
            :size => get_node_text(node, "Size").to_i,
            :etag => get_node_text(node, "ETag"),
            :last_modified => get_node_text(node, "LastModified") {|x| Time.parse(x)}
          )
        end || []

        more = Hash[
          {
            :prefix => 'Prefix',
            :delimiter => 'Delimiter',
            :limit => 'MaxKeys',
            :marker => 'Marker',
            :next_marker => 'NextMarker',
            :truncated => 'IsTruncated',
            :encoding => 'EncodingType'
          }.map do |k, v|
            [k, get_node_text(doc.root, v)]
          end].select {|_, v| v != nil}

        more.update(
          :limit => wrap(more[:limit]) {|x| x.to_i},
          :truncated => wrap(more[:truncated]) {|x| x.to_bool},
          :delimiter => wrap(more[:delimiter]) {|x| decode_key(x, encoding)},
          :marker => wrap(more[:marker]) {|x| decode_key(x, encoding)},
          :next_marker => wrap(more[:next_marker]) {|x| decode_key(x, encoding)}
        )

        common_prefixes = []
        doc.css("CommonPrefixes Prefix").map do |node|
          common_prefixes << decode_key(node.text, encoding)
        end
        more[:common_prefixes] = common_prefixes unless common_prefixes.empty?

        logger.debug("Done list object. objects: #{objects}, more: #{more}")

        [objects, more.select {|_, v| v != nil}]
      end

      # Get an object from the bucket. A block is required to handle
      # the object data chunks.
      # @note User can get the whole object or only part of it by specify
      #  the bytes range;
      # @note User can specify conditions to get the object like:
      #  if-modified-since, if-unmodified-since, if-match-etag,
      #  if-unmatch-etag. If the object to get fails to meet the
      #  conditions, it will not be returned;
      # @note User can indicate the server to rewrite the response headers
      #  such as content-type, content-encoding when get the object
      #  by specify the :rewrite options. The specified headers will
      #  be returned instead of the original property of the object.
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param opts [Hash] options
      # @option opts [Array<Integer>] :range bytes range to get from
      #  the object, in the format: xx-yy
      # @option opts [Hash] :condition preconditions to get the object
      #   * :if_modified_since (Time) get the object if its modified
      #     time is later than specified
      #   * :if_unmodified_since (Time) get the object if its
      #     unmodified time if earlier than specified
      #   * :if_match_etag (String) get the object if its etag match
      #     specified
      #   * :if_unmatch_etag (String) get the object if its etag
      #     doesn't match specified
      # @option opts [Hash] :rewrite response headers to rewrite
      #   * :content_type (String) the Content-Type header
      #   * :content_language (String) the Content-Language header
      #   * :expires (Time) the Expires header
      #   * :cache_control (String) the Cache-Control header
      #   * :content_disposition (String) the Content-Disposition header
      #   * :content_encoding (String) the Content-Encoding header
      # @return [OSS::Object] The object meta
      # @yield [String] it gives the data chunks of the object to
      #  the block
      def get_object(bucket_name, object_name, opts = {}, &block)
        logger.debug("Begin get object, bucket: #{bucket_name}, " \
                     "object: #{object_name}")

        range = opts[:range]
        conditions = opts[:condition]
        rewrites = opts[:rewrite]

        raise ClientError.new("Range must be an array contains 2 Integers.") \
                if range and not range.is_a?(Array) and not range.size == 2

        headers = {}
        if range
          r = [range.at(0), range.at(1) - 1].join('-')
          headers['Range'] = "bytes=#{r}"
        end

        set_conditions(headers, conditions) if conditions

        query = {}
        if rewrites
          [
            :content_type,
            :content_language,
            :cache_control,
            :content_disposition,
            :content_encoding
          ].each do |k|
            query["response-#{k.to_s.sub('_', '-')}"] =
              rewrites[k] if rewrites.has_key?(k)
          end
          query["response-expires"] =
            rewrites[:expires].httpdate if rewrites.has_key?(:expires)
        end

        h, _ = @http.get(
             {:bucket => bucket_name, :object => object_name},
             {:headers => headers, :query => query}) {|chunk| yield chunk if block_given?}

        metas = {}
        meta_prefix = 'x_oss_meta_'
        h.select{ |k, _| k.to_s.start_with?(meta_prefix) }.each do |k, v|
          metas[k.to_s.sub(meta_prefix, '')] = v.to_s
        end

        obj = Object.new(
          :key => object_name,
          :type => h[:x_oss_object_type],
          :size => wrap(h[:content_length]) {|x| x.to_i},
          :etag => h[:etag],
          :metas => metas,
          :last_modified => wrap(h[:last_modified]) {|x| Time.parse(x)})

        logger.debug("Done get object")

        obj
      end

      # Get the object meta rather than the whole object.
      # @note User can specify conditions to get the object like:
      #  if-modified-since, if-unmodified-since, if-match-etag,
      #  if-unmatch-etag. If the object to get fails to meet the
      #  conditions, it will not be returned.
      #
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param opts [Hash] options
      # @option opts [Hash] :condition preconditions to get the
      #  object meta. The same as #get_object
      # @return [OSS::Object] The object meta
      def get_object_meta(bucket_name, object_name, opts = {})
        logger.debug("Begin get object meta, bucket: #{bucket_name}, " \
                     "object: #{object_name}, options: #{opts}")

        headers = {}
        set_conditions(headers, opts[:condition]) if opts[:condition]

        h, _ = @http.head(
             {:bucket => bucket_name, :object => object_name},
             {:headers => headers})

        metas = {}
        meta_prefix = 'x_oss_meta_'
        h.select{ |k, _| k.to_s.start_with?(meta_prefix) }.each do |k, v|
          metas[k.to_s.sub(meta_prefix, '')] = v.to_s
        end

        obj = Object.new(
          :key => object_name,
          :type => h[:x_oss_object_type],
          :size => wrap(h[:content_length]) {|x| x.to_i},
          :etag => h[:etag],
          :metas => metas,
          :last_modified => wrap(h[:last_modified]) {|x| Time.parse(x)})

        logger.debug("Done get object meta")

        obj
      end

      # Copy an object in the bucket. The source object and the dest
      # object must be in the same bucket.
      # @param bucket_name [String] the bucket name
      # @param src_object_name [String] the source object name
      # @param dst_object_name [String] the dest object name
      # @param opts [Hash] options
      # @option opts [String] :acl specify the dest object's
      #  ACL. See {OSS::ACL}
      # @option opts [String] :meta_directive specify what to do
      #  with the object's meta: copy or replace. See
      #  {OSS::MetaDirective}
      # @option opts [String] :content_type the HTTP Content-Type
      #  for the file, if not specified client will try to determine
      #  the type itself and fall back to HTTP::DEFAULT_CONTENT_TYPE
      #  if it fails to do so
      # @option opts [Hash<Symbol, String>] :metas key-value pairs
      #  that serve as the object meta which will be stored together
      #  with the object
      # @option opts [Hash] :condition preconditions to get the
      #  object. See #get_object
      # @return [Hash] the copy result
      #  * :etag [String] the etag of the dest object
      #  * :last_modified [Time] the last modification time of the
      #    dest object
      def copy_object(bucket_name, src_object_name, dst_object_name, opts = {})
        logger.debug("Begin copy object, bucket: #{bucket_name}, " \
                     "source object: #{src_object_name}, dest object: " \
                     "#{dst_object_name}, options: #{opts}")

        headers = {
          'x-oss-copy-source' => @http.get_resource_path(bucket_name, src_object_name),
          'Content-Type' => opts[:content_type]
        }
        (opts[:metas] || {}).each{ |k, v| headers["x-oss-meta-#{k.to_s}"] = v.to_s }

        {
          :acl => 'x-oss-object-acl',
          :meta_directive => 'x-oss-metadata-directive'
        }.each do |k, v|
          headers[v] = opts[k] if opts[k]
        end

        set_copy_conditions(headers, opts[:condition]) if opts[:condition]

        _, body = @http.put(
          {:bucket => bucket_name, :object => dst_object_name},
          {:headers => headers})

        doc = parse_xml(body)
        copy_result = {
          :last_modified => get_node_text(
            doc.root, 'LastModified') {|x| Time.parse(x)},
          :etag => get_node_text(doc.root, 'ETag')
        }.select {|_, v| v != nil}

        logger.debug("Done copy object")

        copy_result
      end

      # Delete an object from the bucket
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      def delete_object(bucket_name, object_name)
        logger.debug("Begin delete object, bucket: #{bucket_name}, " \
                     "object:  #{object_name}")

        @http.delete({:bucket => bucket_name, :object => object_name})

        logger.debug("Done delete object")
      end

      # Batch delete objects
      # @param bucket_name [String] the bucket name
      # @param object_names [Enumerator<String>] the object names
      # @param opts [Hash] options
      # @option opts [Boolean] :quiet indicates whether the server
      #  should return the delete result of the objects
      # @option opts [String] :encoding-type the encoding type for
      #  object key in the response body, only
      #  {OSS::KeyEncoding::URL} is supported now
      # @return [Array<String>] object names that have been
      #  successfully deleted or empty if :quiet is true
      def batch_delete_objects(bucket_name, object_names, opts = {})
        logger.debug("Begin batch delete object, bucket: #{bucket_name}, " \
                     "objects: #{object_names}, options: #{opts}")

        sub_res = {'delete' => nil}
        body = Nokogiri::XML::Builder.new do |xml|
          xml.Delete {
            xml.Quiet opts[:quiet]? true : false
            object_names.each do |o|
              xml.Object {
                xml.Key o
              }
            end
          }
        end.to_xml

        query = {}
        query['encoding-type'] = opts[:encoding] if opts[:encoding]

        _, body = @http.post(
             {:bucket => bucket_name, :sub_res => sub_res},
             {:query => query, :body => body})

        deleted = []
        unless opts[:quiet]
          doc = parse_xml(body)
          encoding = get_node_text(doc.root, 'EncodingType')
          doc.css("Deleted").map do |n|
            deleted << get_node_text(n, 'Key') {|x| decode_key(x, encoding)}
          end
        end

        logger.debug("Done delete object")

        deleted
      end

      # Update object acl
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param acl [String] the object's ACL. See {OSS::ACL}
      def update_object_acl(bucket_name, object_name, acl)
        logger.debug("Begin update object acl, bucket: #{bucket_name}, " \
                     "object: #{object_name}, acl: #{acl}")

        sub_res = {'acl' => nil}
        headers = {'x-oss-object-acl' => acl}

        @http.put(
          {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
          {:headers => headers})

        logger.debug("Done update object acl")
      end

      # Get object acl
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # [return] the object's acl. See {OSS::ACL}
      def get_object_acl(bucket_name, object_name)
        logger.debug("Begin get object acl, bucket: #{bucket_name}, " \
                     "object: #{object_name}")

        sub_res = {'acl' => nil}
        _, body = @http.get(
             {:bucket => bucket_name, :object => object_name, :sub_res => sub_res})

        doc = parse_xml(body)
        acl = get_node_text(doc.at_css("AccessControlList"), 'Grant')

        logger.debug("Done get object acl")

        acl
      end

      # Get object CORS rule
      # @note this is usually used by browser to make a "preflight"
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param origin [String] the Origin of the reqeust
      # @param method [String] the method to request access:
      #  Access-Control-Request-Method
      # @param headers [Array<String>] the headers to request access:
      #  Access-Control-Request-Headers
      # @return [CORSRule] the CORS rule of the object
      def get_object_cors(bucket_name, object_name, origin, method, headers = [])
        logger.debug("Begin get object cors, bucket: #{bucket_name}, object: " \
                     "#{object_name}, origin: #{origin}, method: #{method}, " \
                     "headers: #{headers.join(',')}")

        h = {
          'Origin' => origin,
          'Access-Control-Request-Method' => method,
          'Access-Control-Request-Headers' => headers.join(',')
        }

        return_headers, _ = @http.options(
                          {:bucket => bucket_name, :object => object_name},
                          {:headers => h})

        logger.debug("Done get object cors")

        CORSRule.new(
          :allowed_origins => return_headers[:access_control_allow_origin],
          :allowed_methods => return_headers[:access_control_allow_methods],
          :allowed_headers => return_headers[:access_control_allow_headers],
          :expose_headers => return_headers[:access_control_expose_headers],
          :max_age_seconds => return_headers[:access_control_max_age]
        )
      end

      ##
      # Multipart uploading
      #

      # Initiate a a multipart uploading transaction
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param opts [Hash] options
      # @option opts [String] :content_type the HTTP Content-Type
      #  for the file, if not specified client will try to determine
      #  the type itself and fall back to HTTP::DEFAULT_CONTENT_TYPE
      #  if it fails to do so
      # @option opts [Hash<Symbol, String>] :metas key-value pairs
      #  that serve as the object meta which will be stored together
      #  with the object
      # @return [String] the upload id
      def begin_multipart(bucket_name, object_name, opts = {})
        logger.info("Begin begin_multipart, bucket: #{bucket_name}, " \
                    "object: #{object_name}, options: #{opts}")

        sub_res = {'uploads' => nil}
        headers = {'Content-Type' => opts[:content_type]}
        (opts[:metas] || {}).each{ |k, v| headers["x-oss-meta-#{k.to_s}"] = v.to_s }

        _, body = @http.post(
             {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
             {:headers => headers})

        doc = parse_xml(body)
        txn_id = get_node_text(doc.root, 'UploadId')

        logger.info("Done begin_multipart")

        txn_id
      end

      # Upload a part in a multipart uploading transaction.
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param txn_id [String] the upload id
      # @param part_no [Integer] the part number
      # @yield [HTTP::StreamWriter] a stream writer is
      #  yielded to the caller to which it can write chunks of data
      #  streamingly
      def upload_part(bucket_name, object_name, txn_id, part_no, &block)
        raise ClientError.new('Missing block in upload_part') unless block

        logger.debug("Begin upload part, bucket: #{bucket_name}, object: " \
                     "#{object_name}, txn id: #{txn_id}, part No: #{part_no}")

        sub_res = {'partNumber' => part_no, 'uploadId' => txn_id}
        headers, _ = @http.put(
          {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
          {:body => HTTP::StreamPayload.new(&block)})

        logger.debug("Done upload part")

        Multipart::Part.new(:number => part_no, :etag => headers[:etag])
      end

      # Upload a part in a multipart uploading transaction by copying
      # from an existent object as the part's content. It may copy
      # only part of the object by specifying the bytes range to read.
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param txn_id [String] the upload id
      # @param part_no [Integer] the part number
      # @param source_object [String] the source object name to copy from
      # @param opts [Hash] options
      # @option opts [Array<Integer>] :range the bytes range to
      #  copy, int the format: [begin(inclusive), end(exclusive]
      # @option opts [Hash] :condition preconditions to copy the
      #  object. See #get_object
      def upload_part_from_object(
            bucket_name, object_name, txn_id, part_no, source_object, opts = {})
        logger.debug("Begin upload part from object, bucket: #{bucket_name}, " \
                     "object: #{object_name}, txn id: #{txn_id}, part No: #{part_no}, " \
                     "source object: #{source_object}, options: #{opts}")

        range = opts[:range]
        conditions = opts[:condition]

        raise ClientError.new("Range must be an array contains 2 int.") \
                if range and not range.is_a?(Array) and not range.size == 2

        headers = {
          'x-oss-copy-source' =>
            @http.get_resource_path(bucket_name, source_object)
        }
        if range
          r = [range.at(0), range.at(1) - 1].join('-')
          headers['Range'] = "bytes=#{r}"
        end

        set_copy_conditions(headers, conditions) if conditions

        sub_res = {'partNumber' => part_no, 'uploadId' => txn_id}

        headers, _ = @http.put(
          {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
          {:headers => headers})

        logger.debug("Done upload_part_from_object")

        Multipart::Part.new(:number => part_no, :etag => headers[:etag])
      end

      # Complete a multipart uploading transaction
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param txn_id [String] the upload id
      # @param parts [Array<Multipart::Part>] all the
      #  parts in this transaction
      def commit_multipart(bucket_name, object_name, txn_id, parts)
        logger.info("Begin commit_multipart, txn id: #{txn_id}, " \
                    "parts: #{parts.map(&:to_s)}")

        sub_res = {'uploadId' => txn_id}

        body = Nokogiri::XML::Builder.new do |xml|
          xml.CompleteMultipartUpload {
            parts.each do |p|
              xml.Part {
                xml.PartNumber p.number
                xml.ETag p.etag
              }
            end
          }
        end.to_xml

        @http.post(
          {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
          {:body => body})

        logger.info("Done commit_multipart")
      end

      # Abort a multipart uploading transaction
      # @note All the parts are discarded after abort. For some parts
      #  being uploaded while the abort happens, they may not be
      #  discarded. Call abort_multipart several times for this
      #  situation.
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param txn_id [String] the upload id
      def abort_multipart(bucket_name, object_name, txn_id)
        logger.info("Begin abort_multipart, txn id: #{txn_id}")

        sub_res = {'uploadId' => txn_id}

        @http.delete(
          {:bucket => bucket_name, :object => object_name, :sub_res => sub_res})

        logger.info("Done abort_multipart")
      end

      # Get a list of all the on-going multipart uploading
      # transactions. That is: thoses started and not aborted.
      # @param bucket_name [String] the bucket name
      # @param opts [Hash] options:
      # @option opts [String] :id_marker return only thoese transactions with
      #  txn id after :id_marker
      # @option opts [String] :key_marker the object key marker for
      #  a multipart upload transaction.
      #  1. if +:id_marker+ is not set, return only those
      #     transactions with object key *after* +:key_marker+;
      #  2. if +:id_marker+ is set, return only thoese transactions
      #     with object key *equals* +:key_marker+ and txn id after
      #     +:id_marker+
      # @option opts [String] :prefix the prefix of the object key
      #  for a multipart upload transaction. if set only return
      #  those transactions with the object key prefixed with it
      # @option opts [String] :delimiter the delimiter for the
      #  object key for a multipart upload transaction.
      # @option opts [String] :encoding the encoding of object key
      #  in the response body. Only {OSS::KeyEncoding::URL} is
      #  supported now.
      # @return [Array<Multipart::Transaction>, Hash]
      #  the returned transactions and a hash including next tokens,
      #  which includes:
      #  * :prefix [String] the prefix used
      #  * :delimiter [String] the delimiter used
      #  * :limit [Integer] the limit used
      #  * :id_marker [String] the upload id marker used
      #  * :next_id_marker [String] upload id marker to continue list
      #    multipart transactions
      #  * :key_marker [String] the object key marker used
      #  * :next_key_marker [String] object key marker to continue
      #    list multipart transactions
      #  * :truncated [Boolean] whether there are more transactions
      #    to be returned
      #  * :encoding [String] the object key encoding used
      def list_multipart_transactions(bucket_name, opts = {})
        logger.debug("Begin list multipart transactions, bucket: #{bucket_name}, " \
                     "opts: #{opts}")

        sub_res = {'uploads' => nil}
        params = {
          'prefix' => opts[:prefix],
          'delimiter' => opts[:delimiter],
          'upload-id-marker' => opts[:id_marker],
          'key-marker' => opts[:key_marker],
          'max-uploads' => opts[:limit],
          'encoding-type' => opts[:encoding]
        }.select {|_, v| v != nil}

        _, body = @http.get(
          {:bucket => bucket_name, :sub_res => sub_res},
          {:query => params})

        doc = parse_xml(body)

        encoding = get_node_text(doc.root, 'EncodingType')

        txns = doc.css("Upload").map do |node|
          Multipart::Transaction.new(
            :id => get_node_text(node, "UploadId"),
            :object => get_node_text(node, "Key") {|x| decode_key(x, encoding)},
            :bucket => bucket_name,
            :creation_time => get_node_text(node, "Initiated") {|t| Time.parse(t)}
          )
        end || []

        more = Hash[
          {
            :prefix => 'Prefix',
            :delimiter => 'Delimiter',
            :limit => 'MaxUploads',
            :id_marker => 'UploadIdMarker',
            :next_id_marker => 'NextUploadIdMarker',
            :key_marker => 'KeyMarker',
            :next_key_marker => 'NextKeyMarker',
            :truncated => 'IsTruncated',
            :encoding => 'EncodingType'
          }.map do |k, v|
            [k, get_node_text(doc.root, v)]
          end].select {|_, v| v != nil}

        more.update(
          :limit => wrap(more[:limit]) {|x| x.to_i},
          :truncated => wrap(more[:truncated]) {|x| x.to_bool},
          :delimiter => wrap(more[:delimiter]) {|x| decode_key(x, encoding)},
          :key_marker => wrap(more[:key_marker]) {|x| decode_key(x, encoding)},
          :next_key_marker =>
            wrap(more[:next_key_marker]) {|x| decode_key(x, encoding)}
        )

        logger.debug("Done list_multipart_transactions")

        [txns, more.select {|_, v| v != nil}]
      end

      # Get a list of parts that are successfully uploaded in a
      # transaction.
      # @param txn_id [String] the upload id
      # @param opts [Hash] options:
      # @option opts [Integer] :marker the part number marker after
      #  which to return parts
      # @option opts [Integer] :limit max number parts to return
      # @return [Array<Multipart::Part>, Hash] the returned parts and
      #  a hash including next tokens, which includes:
      #  * :marker [Integer] the marker used
      #  * :limit [Integer] the limit used
      #  * :next_marker [Integer] marker to continue list parts
      #  * :truncated [Boolean] whether there are more parts to be
      #    returned
      def list_parts(bucket_name, object_name, txn_id, opts = {})
        logger.debug("Begin list_parts, bucket: #{bucket_name}, object: " \
                     "#{object_name}, txn id: #{txn_id}, options: #{opts}")

        sub_res = {'uploadId' => txn_id}
        params = {
          'part-number-marker' => opts[:marker],
          'max-parts' => opts[:limit],
          'encoding-type' => opts[:encoding]
        }.select {|_, v| v != nil}

        _, body = @http.get(
          {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
          {:query => params})

        doc = parse_xml(body)
        parts = doc.css("Part").map do |node|
          Multipart::Part.new(
            :number => get_node_text(node, 'PartNumber') {|x| x.to_i},
            :etag => get_node_text(node, 'ETag'),
            :size => get_node_text(node, 'Size') {|x| x.to_i},
            :last_modified =>
              get_node_text(node, 'LastModified') {|x| Time.parse(x)})
        end || []

        more = Hash[
          {
            :limit => 'MaxParts',
            :marker => 'PartNumberMarker',
            :next_marker => 'NextPartNumberMarker',
            :truncated => 'IsTruncated',
            :encoding => 'EncodingType'
          }.map do |k, v|
            [k, get_node_text(doc.root, v)]
          end].select {|k, v| v != nil}

        more.update(
          :limit => wrap(more[:limit]) {|x| x.to_i},
          :truncated => wrap(more[:truncated]) {|x| x.to_bool}
        )

        logger.debug("Done list_parts")

        [parts, more.select {|_, v| v != nil}]
      end

      private

      # Parse body content to xml document
      # @param content [String] the xml content
      # @return [Nokogiri::XML::Document] the parsed document
      def parse_xml(content)
        doc = Nokogiri::XML(content) do |config|
          config.options |= Nokogiri::XML::ParseOptions::NOBLANKS
        end

        doc
      end

      # Get the text of a xml node
      # @param node [Nokogiri::XML::Node] the xml node
      # @param tag [String] the node tag
      # @yield [String] the node text is given to the block
      def get_node_text(node, tag, &block)
        n = node.at_css(tag) if node
        value = n.text if n
        value = yield value if block and value

        value
      end

      # Decode object key using encoding. If encoding is nil it
      # returns the key directly.
      # @param key [String] the object key
      # @param encoding [String] the encoding used
      # @return [String] the decoded key
      def decode_key(key, encoding)
        return key unless encoding

        raise ClientError.new("Unsupported key encoding: #{encoding}") \
                  unless KeyEncoding.include?(encoding)

        if encoding == KeyEncoding::URL
          return CGI.unescape(key)
        end
      end

      # Transform x if x is not nil
      # @param x [Object] the object to transform
      # @yield [Object] the object if given to the block
      # @return [Object] the transformed object
      def wrap(x, &block)
        x == nil ? nil : yield(x)
      end

      # Set conditions in HTTP headers
      # @param headers [Hash] the http headers
      # @param conditions [Hash] the conditions
      def set_conditions(headers, conditions)
        {
          :if_modified_since => 'If-Modified-Since',
          :if_unmodified_since => 'If-Unmodified-Since',
        }.each do |k, v|
          headers[v] = conditions[k].httpdate if conditions.has_key?(k)
        end
        {
          :if_match_etag => 'If-Match',
          :if_unmatch_etag => 'If-None-Match'
        }.each do |k, v|
          headers[v] = conditions[k] if conditions.has_key?(k)
        end
      end

      # Set copy conditions in HTTP headers
      # @param headers [Hash] the http headers
      # @param conditions [Hash] the conditions
      def set_copy_conditions(headers, conditions)
        {
          :if_modified_since => 'x-oss-copy-source-if-modified-since',
          :if_unmodified_since => 'x-oss-copy-source-if-unmodified-since',
        }.each do |k, v|
            headers[v] = conditions[k].httpdate if conditions.has_key?(k)
        end

        {
          :if_match_etag => 'x-oss-copy-source-if-match',
          :if_unmatch_etag => 'x-oss-copy-source-if-none-match'
        }.each do |k, v|
          headers[v] = conditions[k] if conditions.has_key?(k)
        end
      end

    end # Protocol
  end # OSS
end # Aliyun
