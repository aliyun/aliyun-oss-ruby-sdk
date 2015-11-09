# -*- encoding: utf-8 -*-

require 'rest-client'
require 'nokogiri'
require 'time'

module Aliyun
  module OSS

    ##
    # Protocol implement the OSS Open API which is low-level. User
    # should refer to Aliyun::OSS::Client for normal use.
    #
    class Protocol

      STREAM_CHUNK_SIZE = 16 * 1024

      class << self

        include Logging

        # 列出当前所有的bucket
        # [opts] 可能的选项
        #     [:prefix] 如果设置，则只返回以它为前缀的bucket
        #     [:marker] 如果设置，则从从marker后开始返回bucket，*不包含marker*
        #     [:limit] 如果设置，则最多返回limit个bucket
        # [return] [buckets, more]，其中buckets是bucket数组，more是一个Hash，可能
        # 包含的值是：
        #     [:prefix] 此次查询的前缀
        #     [:marker] 此次查询的marker
        #     [:limit] 此次查询的limit
        #     [:next_marker] 下次查询的marker
        #     [:truncated] 这次查询是否被截断（还有更多的bucket没有返回）
        # *注意：如果所有的bucket都已经返回，more将是空的*
        def list_buckets(opts = {})
          logger.info('Begin list bucket')

          params = {
            'prefix' => opts[:prefix],
            'marker' => opts[:marker],
            'max-keys' => opts[:limit]
          }.select {|k, v| v}

          _, body = HTTP.get( {}, {:query => params})
          doc = parse_xml(body)

          buckets = doc.css("Buckets Bucket").map do |node|
            Bucket.new(
              :name => get_node_text(node, "Name"),
              :location => get_node_text(node, "Location"),
              :creation_time =>
                get_node_text(node, "CreationDate") {|t| Time.parse(t)}
            )
          end

          more = Hash[{
                        :prefix => 'Prefix',
                        :limit => 'MaxKeys',
                        :marker => 'Marker',
                        :next_marker => 'NextMarker',
                        :truncated => 'IsTruncated'
                      }.map do |k, v|
                        [k, get_node_text(doc.root, v)]
                      end].select {|k, v| v}

          more[:limit] = more[:limit].to_i if more[:limit]
          more[:truncated] = more[:truncated].to_bool if more[:truncated]

          logger.info('Done list bucket')

          [buckets, more]
        end

        # 创建一个bucket
        # [name] bucket的名字
        # [opts] 可选的参数：
        #     [:location] bucket所在的region，例如oss-cn-hangzhou
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

          HTTP.put({:bucket => name}, {:body => body})

          logger.info("Done create bucket")
        end

        # Update bucket acl
        # [name] the bucket name
        # [acl] the bucket acl
        def update_bucket_acl(name, acl)
          logger.info("Begin update bucket acl, name: #{name}, acl: #{acl}")

          sub_res = {'acl' => nil}
          headers = {'x-oss-acl' => acl}
          HTTP.put(
            {:bucket => name, :sub_res => sub_res},
            {:headers => headers, :body => nil})

          logger.info("Done update bucket acl")
        end

        # Get bucket acl
        # [name] the bucket name
        # [return] the acl of this bucket
        def get_bucket_acl(name)
          logger.info("Begin get bucket acl, name: #{name}")

          sub_res = {'acl' => nil}
          _, body = HTTP.get({:bucket => name, :sub_res => sub_res})

          doc = parse_xml(body)
          acl = get_node_text(doc.at_css("AccessControlList"), 'Grant')
          logger.info("Done get bucket acl")

          acl
        end

        # Update bucket logging settings
        # [name] the bucket name
        # [opts] the logging options
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

          HTTP.put(
            {:bucket => name, :sub_res => sub_res},
            {:body => body})

          logger.info("Done update bucket logging")
        end

        # Get bucket logging settings
        # [name] the bucket name
        # [return] a Hash represents the logging settings of this bucket
        def get_bucket_logging(name)
          logger.info("Begin get bucket logging, name: #{name}")

          sub_res = {'logging' => nil}
          _, body = HTTP.get({:bucket => name, :sub_res => sub_res})

          doc = parse_xml(body)
          opts = {:enable => false}

          logging_node = doc.at_css("LoggingEnabled")
          if logging_node
            opts.update(:enable => true)
            opts.update(
              :target_bucket => get_node_text(logging_node, 'TargetBucket'),
              :prefix => get_node_text(logging_node, 'TargetPrefix')
            )
          end
          logger.info("Done get bucket logging")

          opts.select {|_, v| v != nil}
        end

        # Delete bucket logging settings, a.k.a. disable bucket logging
        # [name] the bucket name
        def delete_bucket_logging(name)
          logger.info("Begin delete bucket logging, name: #{name}")

          sub_res = {'logging' => nil}
          HTTP.delete({:bucket => name, :sub_res => sub_res})

          logger.info("Done delete bucket logging")
        end

        # Update bucket website settings
        # [name] the bucket name
        # [opts] the bucket website options
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

          HTTP.put(
            {:bucket => name, :sub_res => sub_res},
            {:body => body})

          logger.info("Done update bucket website")
        end

        # Get bucket website settings
        # [name] the bucket name
        # [return] a Hash represents the website settings of this bucket
        def get_bucket_website(name)
          logger.info("Begin get bucket website, name: #{name}")

          sub_res = {'website' => nil}
          _, body = HTTP.get({:bucket => name, :sub_res => sub_res})

          opts = {}
          doc = parse_xml(body)
          opts.update(
            :index => get_node_text(doc.at_css('IndexDocument'), 'Suffix'),
            :error => get_node_text(doc.at_css('ErrorDocument'), 'Key')
          )

          logger.info("Done get bucket website")

          opts.select {|_, v| v}
        end

        # Delete bucket website settings
        # [name] the bucket name
        def delete_bucket_website(name)
          logger.info("Begin delete bucket website, name: #{name}")

          sub_res = {'website' => nil}
          HTTP.delete({:bucket => name, :sub_res => sub_res})

          logger.info("Done delete bucket website")
        end

        # Update bucket referer
        # [name] the bucket name
        # [opts] the bucket referer options
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

          HTTP.put(
            {:bucket => name, :sub_res => sub_res},
            {:body => body})

          logger.info("Done update bucket referer")
        end

        # Get bucket referer
        # [name] the bucket name
        # [return] a Hash represents the referer settings of this bucket
        def get_bucket_referer(name)
          logger.info("Begin get bucket referer, name: #{name}")

          sub_res = {'referer' => nil}
          _, body = HTTP.get({:bucket => name, :sub_res => sub_res})

          doc = parse_xml(body)
          opts = {
            :allow_empty => get_node_text(doc.root, 'AllowEmptyReferer') {|x| x.to_bool},
            :referers => doc.css("RefererList Referer").map {|n| n.text}
          }

          logger.info("Done get bucket referer")

          opts.select {|_, v| v}
        end

        # Update bucket lifecycle settings
        # [name] the bucket name
        # [rules] the lifecycle rules
        def update_bucket_lifecycle(name, rules)
          logger.info("Begin update bucket lifecycle, name: #{name}, rules: #{rules.map {|r| r.to_s}}")
          sub_res = {'lifecycle' => nil}
          body = Nokogiri::XML::Builder.new do |xml|
            xml.LifecycleConfiguration {
              rules.each do |r|
                xml.Rule {
                  xml.ID r.id if r.id
                  xml.Status r.enabled ? 'Enabled' : 'Disabled'
                  xml.Prefix r.prefix
                  xml.Expiration {
                    if r.expiry.is_a?(Time)
                      xml.Date r.expiry.iso8601
                    elsif r.expiry.is_a?(Fixnum)
                      xml.Days r.expiry
                    else
                      raise ClientError.new("Expiry must be a Time or Fixnum.")
                    end
                  }
                }
              end
            }
          end.to_xml

          HTTP.put(
            {:bucket => name, :sub_res => sub_res},
            {:body => body})

          logger.info("Done update bucket lifecycle")
        end

        # Get bucket lifecycle settings
        # [name] the bucket name
        # [return] Rule[] the lifecycle rules set on this bucket
        def get_bucket_lifecycle(name)
          logger.info("Begin get bucket lifecycle, name: #{name}")

          sub_res = {'lifecycle' => nil}
          _, body = HTTP.get({:bucket => name, :sub_res => sub_res})

          doc = parse_xml(body)
          rules = doc.css("Rule").map do |n|
            days = n.at_css("Expiration Days")
            date = n.at_css("Expiration Date")

            raise Client.new("We can only have one of Date and Days for expiry.") \
                            if (days and date) or (not days and not date)

            Struct::LifeCycleRule.new(
              :id => get_node_text(n, 'ID') {|x| x.to_i},
              :prefix => get_node_text(n, 'Prefix'),
              :enabled => get_node_text(n, 'Status') {|x| x == 'Enabled'},
              :expiry => days ? days.text.to_i : Time.parse(date.text)
            )
          end
          logger.info("Done get bucket lifecycle")

          rules
        end

        # Delete bucket lifecycle settings
        # NOTE: this will delete all lifecycle rules
        # [name] the bucket name
        def delete_bucket_lifecycle(name)
          logger.info("Begin delete bucket lifecycle, name: #{name}")

          sub_res = {'lifecycle' => nil}
          HTTP.delete({:bucket => name, :sub_res => sub_res})

          logger.info("Done delete bucket lifecycle")
        end

        # Set bucket CORS rules
        # [name] the bucket name
        # [rules] the CORS rules
        def set_bucket_cors(name, rules)
          logger.info("Begin set bucket cors, bucket: #{name}, rules: #{rules.map {|r| r.to_s}.join(';')}")
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

          HTTP.put(
            {:bucket => name, :sub_res => sub_res},
            {:body => body})

          logger.info("Done delete bucket lifecycle")
        end

        # Get bucket CORS rules
        # [name] the bucket name
        # [return] the CORS rules for the bucket
        def get_bucket_cors(name)
          logger.info("Begin get bucket cors, bucket: #{name}")

          sub_res = {'cors' => nil}
          _, body = HTTP.get({:bucket => name, :sub_res => sub_res})

          doc = parse_xml(body)
          rules = []

          doc.css("CORSRule").map do |n|
            allowed_origins = n.css("AllowedOrigin").map {|x| x.text}
            allowed_methods = n.css("AllowedMethod").map {|x| x.text}
            allowed_headers = n.css("AllowedHeader").map {|x| x.text}
            expose_headers = n.css("ExposeHeader").map {|x| x.text}
            max_age_seconds = get_node_text(n, 'MaxAgeSeconds') {|x| x.to_i}

            rules << Struct::CORSRule.new(
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
        # [name] the bucket name
        def delete_bucket_cors(name)
          logger.info("Begin delete bucket cors, bucket: #{name}")

          sub_res = {'cors' => nil}

          HTTP.delete({:bucket => name, :sub_res => sub_res})

          logger.info("Done delete bucket cors")
        end

        # 删除一个bucket
        # [name] bucket的名字
        def delete_bucket(name)
          logger.info("Begin delete bucket: #{name}")

          HTTP.delete({:bucket => name})

          logger.info("Done delete bucket")
        end

        # Put an object to the specified bucket, a block is required
        # to provide the object data
        # [bucket_name] the bucket name
        # [object_name] the object name
        # [opts] Options
        #     [:content_type] the HTTP Content-Type for the file, if
        # not specified client will try to determine the type itself
        # and fall back to HTTP::DEFAULT_CONTENT_TYPE if it fails to
        # do so
        # [block] the block is handled the StreamReader which data can
        # be written to
        def put_object(bucket_name, object_name, opts = {}, &block)
          raise ClientError.new('Missing block in put_object') unless block

          logger.info("Begin put object, bucket: #{bucket_name}, object:#{object_name}, \
                      options: #{opts}")

          HTTP.put(
            {:bucket => bucket_name, :object => object_name},
            {:headers => {'Content-Type' => opts[:content_type]},
             :body => HTTP::StreamPayload.new(block)})

          logger.info('Done put object')
        end

        # Put an object to the specified bucket. The object's content
        # is read from a local file specified by +file_path+
        # [bucket_name] the bucket name
        # [object_name] the object name
        # [file_path] the file to read object data
        # [opts] Options
        #     [:content_type] the HTTP Content-Type for the file, if
        # not specified client will try to determine the type itself
        # and fall back to HTTP::DEFAULT_CONTENT_TYPE if it fails to
        # do so
        def put_object_from_file(bucket_name, object_name, file_path, opts = {})
          logger.info("Begin put object from file: #{file_path}, options: #{opts}")

          file = File.open(File.expand_path(file_path))
          content_type = get_content_type(File.expand_path(file_path))
          put_object(
            bucket_name, object_name,
            :content_type => opts[:content_type] || content_type
          ) do |content|
            content << file.read(STREAM_CHUNK_SIZE) unless file.eof?
          end

          logger.info('Done put object from file')
        end

        # Append to an object of a bucket. Create an 'Appendable
        # Object' if the object does not exist. A block is required to
        # provide the appending data.
        # [bucket_name] the bucket name
        # [object_name] the object name
        # [position] the position to append
        # [opts] options
        #     [:content_type] the HTTP Content-Type for the file, if
        # not specified client will try to determine the type itself
        # and fall back to HTTP::DEFAULT_CONTENT_TYPE if it fails to
        # do so
        # [block] the block is handled the StreamReader which data can
        # be written to
        # NOTE:
        #   1. Can not append to a 'Normal Object'
        #   2. The position must equal to the object's size before append
        #   3. The :content_type is only used when the object is created
        def append_object(bucket_name, object_name, position, opts = {}, &block)
          raise ClientError.new('Missing block in append_object') unless block

          logger.info("Begin append object, bucket: #{bucket_name}, object: #{object_name}, \
                      position: #{position}, options: #{opts}")

          sub_res = {'append' => nil, 'position' => position}
          HTTP.post(
            {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
            {:headers => {'Content-Type' => opts[:content_type]},
             :body => HTTP::StreamPayload.new(block)})

          logger.info('Done append object')
        end

        # Append to an object of a bucket. Create an 'Appendable
        # Object' if the object does not exist. The appending data is
        # read from a local file specified by +file_path+.
        # [bucket_name] the bucket name
        # [object_name] the object name
        # [position] the position to append
        # [file_path] the local file to read from
        # [opts] options
        #     [:content_type] the HTTP Content-Type for the file, if
        # not specified client will try to determine the type itself
        # and fall back to HTTP::DEFAULT_CONTENT_TYPE if it fails to
        # do so
        # NOTE:
        #   1. Can not append to a 'Normal Object'
        #   2. The position must equal to the object's size before append
        #   3. The :content_type is only used when the object is created
        def append_object_from_file(
              bucket_name, object_name, position, file_path, opts = {}, &block)

          logger.info("Begin append object, bucket: #{bucket_name}, object: #{object_name}, \
                      position: #{position}, file: #{file_path}, options: #{opts}")

          file = File.open(File.expand_path(file_path))
          content_type = get_content_type(File.expand_path(file_path))
          append_object(
            bucket_name, object_name, position,
            :content_type => opts[:content_type] || content_type
          ) do |content|
            content << file.read(STREAM_CHUNK_SIZE) unless file.eof?
          end

          logger.info('Done append object')
        end

        # 列出指定的bucket中的所有object
        # [bucket_name] bucket的名字
        # [opts] 可选的参数，可能的值有：
        #    [:prefix] 返回的object key的前缀
        #    [:marker] 如果设置，则从marker之后开始返回object，*注意：不包含marker*
        #    [:limit] 最多返回的object的个数
        #    [:delimiter] 如果指定，则结果中包含一个common prefix数组，
        # 表示所有object的公共前缀。例如有以下objects：
        #     /foo/bar/obj1
        #     /foo/bar/obj2
        #     ...
        #     /foo/bar/obj9999999
        #     /foo/xx/
        # 指定foo/为prefix，/为delimiter，则返回的common prefix为
        # /foo/bar/, /foo/xxx/
        #    [:encoding] 返回的object key的编码方式
        # [return] [objects, more] 前者是返回的object数组，后者是一个
        # Hash，可能包含：
        #    [:common_prefixes] common prefix数组
        #    [:prefix] 所使用的prefix
        #    [:delimiter] 所使用的delimiter
        #    [:limit] 所使用的limit
        #    [:marker] 所使用的marker
        #    [:next_marker] 下次查询的marker
        #    [:truncated] 本次查询是否被截断（还有更多的object待返回）
        #    [:encoding] 返回结果中object key和prefix等的编码方式
        def list_objects(bucket_name, opts = {})
          logger.info("Begin list object, bucket: #{bucket_name}")

          params = {
            'prefix' => opts[:prefix],
            'delimiter' => opts[:delimiter],
            'marker' => opts[:marker],
            'max-keys' => opts[:limit],
            'encoding-type' => opts[:encoding]
          }.select {|k, v| v}

          _, body = HTTP.get({:bucket => bucket_name}, {:query => params})

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
          end

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
            end].select {|k, v| v}

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

          logger.info("Done list object")

          [objects, more.select {|_, v| v != nil}]
        end

        # Get an object from the bucket. Data chunks are handled to
        # the block passed in.
        # User can get the whole object or only part of it by specify
        # the bytes range;
        # User can specify conditions to get the object like:
        # if-modified-since, if-unmodified-since, if-match-etag,
        # if-unmatch-etag. If the object to get fails to meet the
        # conditions, it will not be returned;
        # User can indicate the server to rewrite the response headers
        # such as content-type, content-encoding when get the object
        # by specify the :rewrite options. The specified headers will
        # be returned instead of the original property of the object.
        # [bucket_name] the bucket name
        # [object_name] the object name
        # [opts] options
        #     [:range] bytes range to read in the format: xx-yy
        #     [:condition] preconditions to get the object:
        #       [:if_modified_since] the modified time
        #       [:if_unmodified_since] the unmodified time
        #       [:if_match_etag] the etag to expect to match
        #       [:if_unmatch_etag] the etag to expect to not match
        #     [:rewrite] response headers to rewrite
        #       [:content_type] the Content-Type header
        #       [:content_language] the Content-Language header
        #       [:expires] the Expires header
        #       [:cache_control] the Cache-Control header
        #       [:content_disposition] the Content-Disposition header
        #       [:content_encoding] the Content-Encoding header
        # [block] the block is handled data chunk of the object
        def get_object(bucket_name, object_name, opts = {}, &block)
          logger.info("Begin get object, bucket: #{bucket_name}, object: #{object_name}")

          range = opts[:range]
          conditions = opts[:condition]
          rewrites = opts[:rewrite]

          raise ClientError.new("Range must be an array contains 2 int.") \
                               if range and not range.is_a?(Array) and not range.size == 2

          headers = {}
          headers['Range'] = range.join('-') if range
          {
            :if_modified_since => 'If-Modified-Since',
            :if_unmodified_since => 'If-Unmodified-Since',
            :if_match_etag => 'If-Match',
            :if_unmatch_etag => 'If-None-Match'
          }.each do |k, v|
            headers[v] = conditions[k] if conditions and conditions[k]
          end

          query = {}
          [
            :content_type,
            :content_language,
            :expires,
            :cache_control,
            :content_disposition,
            :content_encoding
          ].each do |k|
            query["response-#{k.to_s.sub('_', '-')}"] =
              rewrites[k] if rewrites and rewrites[k]
          end

          HTTP.get(
            {:bucket => bucket_name, :object => object_name},
            {:headers => headers, :query => query}) {|chunk| yield chunk}

          logger.info("Done get object")
        end

        # Get an object from the bucket and write the content into a
        # local file.
        # [bucket_name] the bucket name
        # [object_name] the object name
        # [file_path] the local file to write
        # [opts] options referer to get_object for details
        def get_object_to_file(bucket_name, object_name, file_path, opts = {})
          logger.info("Begin get object to file, bucket: #{bucket_name}, \
                      object: #{object_name}, file: #{file_path}, options: #{opts}")

          File.open(File.expand_path(file_path), 'w') do |f|
            get_object(bucket_name, object_name, opts) {|chunk| f.write(chunk)}
          end

          logger.info("Done get object to file")
        end

        # Copy an object in the bucket. The source object and the dest
        # object must be in the same bucket.
        # [bucket_name] the bucket name
        # [src_object_name] the source object name
        # [dst_object_name] the dest object name
        # [opts] options
        #     [:acl] the dest object's Struct::ACL
        #     [:meta_directive] what to do with the object's meta:
        # copy or replace; see Struct::MetaDirective
        #     [:condition] preconditions to get the object:
        #       [:if_modified_since] the modified time
        #       [:if_unmodified_since] the unmodified time
        #       [:if_match_etag] the etag to expect to match
        #       [:if_unmatch_etag] the etag to expect to not match
        # [return] a Hash that includes :etag and :last_modified of the dest object
        def copy_object(bucket_name, src_object_name, dst_object_name, opts = {})
          logger.info("Begin copy object, bucket: #{bucket_name}, source object: \
                      #{src_object_name}, dest object: #{dst_object_name}, options: #{opts}")

          headers = {
            'x-oss-copy-source' =>
              HTTP.get_resource_path(bucket_name, src_object_name)
          }

          {
            :acl => 'x-oss-object-acl',
            :meta_directive => 'x-oss-metadata-directive'
          }.each do |k, v|
            headers[v] = opts[k] if opts[k]
          end

          conditions = opts[:condition]
          {
            :if_modified_since => 'x-oss-copy-source-if-modified-since',
            :if_unmodified_since => 'x-oss-copy-source-if-unmodified-since',
            :if_match_etag => 'x-oss-copy-source-if-match',
            :if_unmatch_etag => 'x-oss-copy-source-if-none-match'
          }.each do |k, v|
            headers[v] = conditions[k] if conditions and conditions[k]
          end

          _, body = HTTP.put(
            {:bucket => bucket_name, :object => dst_object_name},
            {:headers => headers})

          doc = parse_xml(body)
          copy_result = {
            :last_modified => get_node_text(
              doc.root, 'LastModified') {|x| Time.parse(x)},
            :etag => get_node_text(doc.root, 'ETag')
          }.select {|k, v| v}

          logger.info("Done copy object")

          copy_result
        end

        # 删除指定的bucket中的指定object
        # [bucket_name] bucket的名字
        # [object_name] object的名字
        def delete_object(bucket_name, object_name)
          logger.info("Begin delete object, bucket: #{bucket_name}, object: #{object_name}")

          HTTP.delete({:bucket => bucket_name, :object => object_name})

          logger.info("Done delete object")
        end

        # Batch delete objects
        # [bucket_name] the bucket name
        # [object_names] the object names to delete
        # [opts] options
        #     [:quiet] if set to true, return empty list
        #     [:encoding-type] the encoding type for object key, only
        # supports 'url' now
        # [return] object names that are successfully deleted, or []
        # if :quiet is true
        def batch_delete_objects(bucket_name, object_names, opts = {})
          logger.info("Begin batch delete object, bucket: #{bucket_name}, \
                      objects: #{object_names}, options: #{opts}")

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

          _, body = HTTP.post(
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

          logger.info("Done delete object")

          deleted
        end

        # Update object acl
        # [bucket_name] the bucket name
        # [object_name] the object name
        # [acl] the object acl
        def update_object_acl(bucket_name, object_name, acl)
          logger.debug("Begin update object acl, bucket: #{bucket_name}, object: #{object_name}, acl: #{acl}")

          sub_res = {'acl' => nil}
          headers = {'x-oss-acl' => acl}

          HTTP.put(
            {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
            {:headers => headers})

          logger.debug("Done update object acl")
        end

        # Get object acl
        # [bucket_name] the bucket name
        # [object_name] the object name
        # [return] the object acl
        def get_object_acl(bucket_name, object_name)
          logger.debug("Begin get object acl, bucket: #{bucket_name}, object: #{object_name}")

          sub_res = {'acl' => nil}
          _, body = HTTP.get(
               {:bucket => bucket_name, :object => object_name, :sub_res => sub_res})

          doc = parse_xml(body)
          acl = get_node_text(doc.at_css("AccessControlList"), 'Grant')

          logger.debug("Done get object acl")

          acl
        end

        # Get object CORS rule
        # NOTE: this is usually used by browser to make a 'preflight'
        # [bucket_name] the bucket name
        # [object_name] the object name
        # [origin] the origin of the request
        # [method] the method to request access: Access-Control-Request-Method
        # [headers] the method to request access: Access-Control-Request-Headers
        # [return] CORSRule that describe access rule of the object
        def get_object_cors(bucket_name, object_name, origin, method, headers = [])
          logger.debug("Begin get object cors, bucket: #{bucket_name}, object: #{object_name} \
                        origin: #{origin}, method: #{method}, headers: #{headers.join(',')}")

          h = {
            'Origin' => origin,
            'Access-Control-Request-Method' => method,
            'Access-Control-Request-Headers' => headers.join(',')
          }

          return_headers, _ = HTTP.options(
                            {:bucket => bucket_name, :object => object_name},
                            {:headers => h})

          logger.debug("Done get object cors")

          Struct::CORSRule.new(
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

        # Begin a a multipart uploading transaction
        # [bucket_name] the bucket name
        # [object_name] the object name
        # [opts] options
        # [return] the txn id
        def begin_multipart(bucket_name, object_name, opts = {})
          logger.debug("Begin begin_multipart, bucket: #{bucket_name}, object: #{object_name}, options: #{opts}")

          sub_res = {'uploads' => nil}
          _, body = HTTP.post(
            {:bucket => bucket_name, :object => object_name, :sub_res => sub_res})

          doc = parse_xml(body)
          txn_id = get_node_text(doc.root, 'UploadId')

          logger.debug("Done begin_multipart")

          txn_id
        end

        # Upload a part in a multipart uploading transaction.
        # [bucket_name] the bucket name
        # [object_name] the object name
        # [txn_id] the txn id
        # [part_no] the part number
        # [block] provide the part content
        def upload_part(bucket_name, object_name, txn_id, part_no, &block)
          raise ClientError.new('Missing block in upload_part') unless block

          logger.debug("Begin upload part, bucket: #{bucket_name}, object: #{object_name}, txn id: #{txn_id}, part No: #{part_no}")

          sub_res = {'partNumber' => part_no, 'uploadId' => txn_id}
          headers, _ = HTTP.put(
            {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
            {:body => HTTP::StreamPayload.new(block)})

          logger.debug("Done upload part")

          Multipart::Part.new(:number => part_no, :etag => headers[:etag])
        end

        # Upload a part in a multipart uploading transaction by copying
        # from an existent object as the part's content. It may copy
        # only part of the object by specifying the bytes range to read.
        # [bucket_name] the bucket name
        # [object_name] the object name
        # [txn_id] the txn id
        # [part_no] the part number
        # [source_object] the source object to copy from
        # [opts] options
        #     [:range] the bytes range to copy: [begin, end)
        #     [:condition] preconditions to copy the object:
        #       [:if_modified_since] the modified time
        #       [:if_unmodified_since] the unmodified time
        #       [:if_match_etag] the etag to expect to match
        #       [:if_unmatch_etag] the etag to expect to not match
        def upload_part_from_object(
              bucket_name, object_name, txn_id, part_no, source_object, opts = {})
          logger.debug("Begin upload part from object, bucket: #{bucket_name}, \
                       object: #{object_name}, txn id: #{txn_id}, part No: #{part_no}, \
                       source object: #{source_object}, options: #{opts}")

          range = opts[:range]
          conditions = opts[:condition]

          raise ClientError.new("Range must be an array contains 2 int.") \
                               if range and not range.is_a?(Array) and not range.size == 2

          headers = {
            'x-oss-copy-source' =>
              HTTP.get_resource_path(bucket_name, source_object)
          }
          headers['Range'] = range.join('-') if range

          {
            :if_modified_since => 'x-oss-copy-source-if-modified-since',
            :if_unmodified_since => 'x-oss-copy-source-if-unmodified-since',
            :if_match_etag => 'x-oss-copy-source-if-match',
            :if_unmatch_etag => 'x-oss-copy-source-if-none-match'
          }.each do |k, v|
            headers[v] = conditions[k] if conditions and conditions[k]
          end

          sub_res = {'partNumber' => part_no, 'uploadId' => txn_id}

          headers, _ = HTTP.put(
            {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
            {:headers => headers})

          logger.debug("Done upload_part_from_object")

          Multipart::Part.new(:number => part_no, :etag => headers[:etag])
        end

        # Commit a multipart uploading transaction
        # [bucket_name] the bucket name
        # [object_name] the object name
        # [txn_id] the txn id
        # [parts] all the parts in this transaction
        def commit_multipart(bucket_name, object_name, txn_id, parts)
          logger.debug("Begin commit_multipart, txn id: #{txn_id}, parts: #{parts}")

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

          HTTP.post(
            {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
            {:body => body})

          logger.debug("Done commit_multipart")
        end

        # Abort a multipart uploading transaction
        # All the parts are discarded after abort. For some parts
        # being uploaded while the abort happens, they may not be
        # discarded. Call abort_multipart several times for this
        # situation.
        # [bucket_name] the bucket name
        # [object_name] the object name
        # [txn_id] the txn id
        def abort_multipart(bucket_name, object_name, txn_id)
          logger.debug("Begin abort_multipart, txn id: #{txn_id}")

          sub_res = {'uploadId' => txn_id}

          HTTP.delete(
            {:bucket => bucket_name, :object => object_name, :sub_res => sub_res})

          logger.debug("Done abort_multipart")
        end

        # Get a list of all the on-going multipart uploading
        # transactions.That is: thoses started and not aborted.
        # [bucket_name] the bucket name
        # [opts] options:
        #    [:id_marker] if set return only thoese transactions with
        # txn id after :id_marker
        #    [:key_marker] 1) if :id_marker is not set, return only
        # those transactions with object key *after* :key_marker; 2) if
        # :id_marker is set, return only thoese transactions with
        # object key *equals* :key_marker and txn id after :id_marker
        #    [:prefix] if set only return those transactions with the
        # object key prefixed with it
        #    [:delimiter] if set return common prefixes
        # [return] [transactions, more]
        def list_multipart_transactions(bucket_name, opts = {})
          logger.debug("Begin list_multipart_transactions, bucket: #{bucket_name}, opts: #{opts}")

          sub_res = {'uploads' => nil}
          params = {
            'prefix' => opts[:prefix],
            'delimiter' => opts[:delimiter],
            'upload-id-marker' => opts[:id_marker],
            'key-marker' => opts[:key_marker],
            'max-uploads' => opts[:limit],
            'encoding-type' => opts[:encoding]
          }.select {|k, v| v}

          _, body = HTTP.get(
            {:bucket => bucket_name, :sub_res => sub_res},
            {:query => params})

          doc = parse_xml(body)

          encoding = get_node_text(doc.root, 'EncodingType')

          txns = doc.css("Upload").map do |node|
            Multipart::Transaction.new(
              :id => get_node_text(node, "UploadId"),
              :object_key => get_node_text(node, "Key") {|x| decode_key(x, encoding)},
              :creation_time => get_node_text(node, "Initiated") {|t| Time.parse(t)}
            )
          end

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
            end].select {|k, v| v}

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
        # [txn_id] the txn id
        # [opts] options:
        #     [:marker] if set only return thoses parts after part
        # number
        #     [:limit] if set return :limit parts at most
        # [return] the parts that are successfully uploaded
        def list_parts(bucket_name, object_name, txn_id, opts = {})
          logger.debug("Begin list_parts, bucket: #{bucket_name}, object: #{object_name}, txn id: #{txn_id}, options: #{opts}")

          sub_res = {'uploadId' => txn_id}
          params = {
            'part-number-marker' => opts[:marker],
            'max-parts' => opts[:limit],
            'encoding-type' => opts[:encoding]
          }.select {|k, v| v}

          _, body = HTTP.get(
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
          end

          more = Hash[
            {
              :limit => 'MaxParts',
              :marker => 'PartNumberMarker',
              :next_marker => 'NextPartNumberMarker',
              :truncated => 'IsTruncated',
              :encoding => 'EncodingType'
            }.map do |k, v|
              [k, get_node_text(doc.root, v)]
            end].select {|k, v| v}

          more.update(
            :limit => wrap(more[:limit]) {|x| x.to_i},
            :truncated => wrap(more[:truncated]) {|x| x.to_bool}
          )

          logger.debug("Done list_parts")

          [parts, more.select {|_, v| v != nil}]
        end

        private

        # 将content解析成xml doc对象
        def parse_xml(content)
          doc = Nokogiri::XML(content) do |config|
            config.options |= Nokogiri::XML::ParseOptions::NOBLANKS
          end

          doc
        end

        # 获取节点下面的tag内容
        def get_node_text(node, tag, &block)
          n = node.at_css(tag) if node
          value = n.text if n
          value = block.call(value) if block and value

          value
        end

        # infer the file's content type using MIME::Types
        def get_content_type(file)
          t = MIME::Types.of(file)
          t.first.content_type unless t.empty?
        end

        # decode object key
        def decode_key(key, encoding)
          return key unless encoding

          raise ClientError.new("Unsupported key encoding: #{encoding}") \
                    unless Struct::KeyEncoding.include?(encoding)

          if encoding == 'url'
            return CGI.unescape(key)
          end
        end

        # transform x if x is not nil
        def wrap(x, &block)
          x == nil ? nil : block.call(x)
        end

      end # self

    end # Protocol

  end # OSS
end # Aliyun
