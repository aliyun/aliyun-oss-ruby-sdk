# -*- encoding: utf-8 -*-

module Aliyun
  module OSS
    ##
    # Bucket is the class for object related operations. It consists of three major functions:
    # 1. bucket related：Gets/Sets bucket settings (e.g. acl, logging, referer,
    #    website, lifecycle, cors, etc）
    # 2. object related：Upload, download, append, copy object, etc
    # 3. multipart related：upload with checkpoint, download with checkpoint.
    class Bucket < Common::Struct::Base

      attrs :name, :location, :creation_time

      def initialize(opts = {}, protocol = nil)
        super(opts)
        @protocol = protocol
      end

      ### Bucket related API ###

      # Gets Bucket ACL
      # @return [String] Bucket的{OSS::ACL ACL}
      def acl
        @protocol.get_bucket_acl(name)
      end

      # Sets Bucket ACL
      # @param acl [String] Bucket的{OSS::ACL ACL}
      def acl=(acl)
        @protocol.put_bucket_acl(name, acl)
      end

      # Gets Bucket logging config
      # @return [BucketLogging] Bucket logging config
      def logging
        @protocol.get_bucket_logging(name)
      end

      # Sets Bucket logging config
      # @param logging [BucketLogging] logging config
      def logging=(logging)
        if logging.enabled?
          @protocol.put_bucket_logging(name, logging)
        else
          @protocol.delete_bucket_logging(name)
        end
      end

      # Gets Bucket website config
      # @return [BucketWebsite] Bucket website config
      def website
        begin
          w = @protocol.get_bucket_website(name)
        rescue ServerError => e
          raise unless e.http_code == 404
        end

        w || BucketWebsite.new
      end

      # Sets Bucket website config
      # @param website [BucketWebsite] website config
      def website=(website)
        if website.enabled?
          @protocol.put_bucket_website(name, website)
        else
          @protocol.delete_bucket_website(name)
        end
      end

      # Gets Bucket referer config
      # @return [BucketReferer] Bucket referer config
      def referer
        @protocol.get_bucket_referer(name)
      end

      # Sets Bucket referer config
      # @param referer [BucketReferer] Referer config
      def referer=(referer)
        @protocol.put_bucket_referer(name, referer)
      end

      # GETS Bucket's lifecycle config
      # @return [Array<OSS::LifeCycleRule>] Bucket's lifecycle config, if it's not set, return [].
      def lifecycle
        begin
          r = @protocol.get_bucket_lifecycle(name)
        rescue ServerError => e
          raise unless e.http_code == 404
        end

        r || []
      end

      # Sets Bucket's lifecycle config
      # @param rules [Array<OSS::LifeCycleRule>] lifecycle rule config.
      # @see OSS::LifeCycleRule for how to set lifecycle rules.
      # @note if rules is empty, the existing lifecycle config will be deleted.
      def lifecycle=(rules)
        if rules.empty?
          @protocol.delete_bucket_lifecycle(name)
        else
          @protocol.put_bucket_lifecycle(name, rules)
        end
      end

      # Gets Bucket's CORS rules
      # @return [Array<OSS::CORSRule>] Bucket's CORS rules. If it's not set, returns [].
      def cors
        begin
          r = @protocol.get_bucket_cors(name)
        rescue ServerError => e
          raise unless e.http_code == 404
        end

        r || []
      end

      # Sets Bucket CORS rules
      # @param rules [Array<OSS::CORSRule>] CORS rules
      # @note If rules are empty, it will delete the existing CORS config.
      def cors=(rules)
        if rules.empty?
          @protocol.delete_bucket_cors(name)
        else
          @protocol.set_bucket_cors(name, rules)
        end
      end

      ### Object related API ###


      # Lists objects in the bucket
      # @param opts [Hash] options for the list operation
      # @option opts [String] :prefix object prefix. If set, it will only return objects whose key has the prefix.
      # @option opts [String] :marker object marker. If set, it will only return objects whose key is greater than the marker.
      # @option opts [String] :delimiter the separator for getting common prefix. The common prefixes are the objects 
      # whose key starting with prefix and ending with the delimiter.
      # @example
      #  If we have the following objects:
      #     /foo/bar/obj1
      #     /foo/bar/obj2
      #     ...
      #     /foo/bar/obj9999999
      #     /foo/xxx/
      #  Use 'foo/' as prefix and '/' as delimiter, then the common prefixes are:
      #  '/foo/bar/', '/foo/xxx/'. They're the subdirectories of directory '/foo/'.
      #  Use prefix and delimiter for getting common prefix could avoid querying all the objects under the bucket.
      #  This is the common practise for iterating the directory structures.
      # @return [Enumerator<Object>] the object could be {OSS::Object} or {String}. In latter case it's the common prefix.
      # @example
      #  all = bucket.list_objects
      #  all.each do |i|
      #    if i.is_a?(Object)
      #      puts "Object: #{i.key}"
      #    else
      #      puts "Common prefix: #{i}"
      #    end
      #  end
      def list_objects(opts = {})
        Iterator::Objects.new(
          @protocol, name, opts.merge(encoding: KeyEncoding::URL)).to_enum
      end

      # Uploads an object to the bucket
      # @param key [String] Object key
      # @param opts [Hash] options for uploading 
      # @option opts [String] :file local file to upload
      # @option opts [String] :content_type content to upload
      #  Content-Type，default is application/octet-stream
      # @option opts [Hash] :metas object's custom meta,which will be stored with object. 
      #  They're returned when {#get_object} are called. The custom metadata's key are not case sensitive.
      #  For example ：{ 'year' => '2015' } is same as {'YEAR' => '2015'}
      # @option opts [Callback] :callback specifies the callback after the operation succeeds.
      #  After the upload succeeds, OSS could send a HTTP POST to user's application--the callback parameter specifies parameters of this post request.
      # @option opts [Hash] :headers specifies the HTTP headers, the headers are case insensitive.
      #   Its values could overwrite the the value set by `:content_type` and `:metas`.
      # @yield [HTTP::StreamWriter] if the block is specified, then the object content is specified by thsi block.
      # @example upload streaming data
      #   put_object('x'){ |stream| 100.times { |i| stream << i.to_s } }
      #   put_object('x'){ |stream| stream << get_data }
      # @example upload file
      #   put_object('x', :file => '/tmp/x')
      # @example specifies Content-Type and metas
      #   put_object('x', :file => '/tmp/x', :content_type => 'text/html',
      #              :metas => {'year' => '2015', 'people' => 'mary'})
      # @example specifies Callback
      #   callback = Aliyun::OSS::Callback.new(
      #     url: 'http://10.101.168.94:1234/callback',
      #     query: {user: 'put_object'},
      #     body: 'bucket=${bucket}&object=${object}'
      #   )
      #
      #   bucket.put_object('files/hello', callback: callback)
      # @raise [CallbackError] If file upload succeeds but callback failed, it will throw this error.
      # @note If `:file` is specified in opts, then block parameter is ignored.
      # @note If `:callback` is specified, then it's possibel that file upload succeeds but callback fails, in which case
      #   the {OSS::CallbackError} is thrown. The call could opt to catch this exception and ignore the callback failure.
      def put_object(key, opts = {}, &block)
        args = opts.dup

        file = args[:file]
        args[:content_type] ||= get_content_type(file) if file
        args[:content_type] ||= get_content_type(key)

        if file
          @protocol.put_object(name, key, args) do |sw|
            File.open(File.expand_path(file), 'rb') do |f|
              sw << f.read(Protocol::STREAM_CHUNK_SIZE) until f.eof?
            end
          end
        else
          @protocol.put_object(name, key, args, &block)
        end
      end

      # Download an object from the bucket
      # @param key [String] Object key.
      # @param opts [Hash] options for downloading objects
      # @option opts [Array<Integer>] :range specifies the exact offset of the object to download.
      #  The range should follow the HTTP Range specification (https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Range).
      # @option opts [String] :file specifies the local file path for store the object to download.
      # @option opts [Hash] :condition specifies the condition to download the file.
      #   * :if_modified_since (Time) if the object's last modified time is later than this value, download the object.
      #   * :if_unmodified_since (Time) if the object's last modified time is earlier than this value, download the object.
      #   * :if_match_etag (String) if the object's ETag matches this value, download the object.
      #   * :if_unmatch_etag (String) if the object's ETag does not match this value, download the object.
      # @option opts [Hash] :headers specifies HTTP headers, they're case insensitive.
      #  The headers' values could overwrite the values set by `:range` and `:condition`.
      # @option opts [Hash] :rewrite specifies the headers the OSS server response should contain for the download request.
      #   * :content_type (String) specifies the response to return Content-Type value
      #   * :content_language (String) specifies the response to return Content-Language value
      #   * :expires (Time) specifies the response to return Expires value.
      #   * :cache_control (String) specifies the response to return Cache-Control value.
      #   * :content_disposition (String) specifies the response to return Content-Disposition value.
      #   * :content_encoding (String) specifies the response to return Content-Encoding value.
      # @return [OSS::Object] returns Object
      # @yield [String] if the block is specified, then the data will be stored in block.
      # @example stremaing data download
      #   get_object('x'){ |chunk| handle_chunk_data(chunk) }
      # @example download object to local file
      #   get_object('x', :file => '/tmp/x')
      # @example specifies condition
      #   get_object('x', :file => '/tmp/x', :condition => {:if_match_etag => 'etag'})
      # @example specifies rewrite header information.
      #   get_object('x', :file => '/tmp/x', :rewrite => {:content_type => 'text/html'})
      # @note If opts contains `:file`，then block is ignored.
      # @note If neither `:file` nor block is specified, then only object meta is returned (no content)
      def get_object(key, opts = {}, &block)
        obj = nil
        file = opts[:file]
        if file
          File.open(File.expand_path(file), 'wb') do |f|
            obj = @protocol.get_object(name, key, opts) do |chunk|
              f.write(chunk)
            end
          end
        elsif block
          obj = @protocol.get_object(name, key, opts, &block)
        else
          obj = @protocol.get_object_meta(name, key, opts)
        end

        obj
      end

      # Updates Object's metas
      # @param key [String] Object's name
      # @param metas [Hash] Object's meta
      # @param conditions [Hash] Specifies the condition to update Object meta.
      #  It's same as the one in {#get_object}
      # @return [Hash] updated file metadatas
      #  * :etag [String] new ETag
      #  * :last_modified [Time] updated last modified time
      def update_object_metas(key, metas, conditions = {})
        @protocol.copy_object(
          name, key, key,
          :meta_directive => MetaDirective::REPLACE,
          :metas => metas,
          :condition => conditions)
      end

      # checks if an object exists or not.
      # @param key [String] Object key.
      # @return [Boolean]  If object exists, returns true; otherwise returns false.
      def object_exists?(key)
        begin
          get_object(key)
          return true
        rescue ServerError => e
          return false if e.http_code == 404
          raise e
        end

        false
      end

      alias :object_exist? :object_exists?

      # Appends content to the object in a bucket. If the object does not exist, create a new one.
      # Appendable Object.
      # @param key [String] Object key
      # @param opts [Hash] opts for appending the object (optional)
      # @option opts [String] :file specifies the local file to read from for the appending.
      # @option opts [String] :content_type sets the content-type for the upload
      #  Content-Type，default is application/octet-stream
      # @option opts [Hash] :metas Sets object meta. These user custom metadata will be stored with object.
      #  And {#get_object} would return these meta.
      #  metas' key are case insensitive. For example:{ 'year' => '2015' }
      # @option opts [Hash] :headers specifies HTTP header, it's case insenstive.
      #  The values would overwrite the one set by `:content_type` and `:metas`.
      # @example append streaming data.
      #   pos = append_object('x', 0){ |stream| 100.times { |i| stream << i.to_s } }
      #   append_object('x', pos){ |stream| stream << get_data }
      # @example append a file
      #   append_object('x', 0, :file => '/tmp/x')
      # @example specifies Content-Type and metas
      #   append_object('x', 0, :file => '/tmp/x', :content_type => 'text/html',
      #                 :metas => {'year' => '2015', 'people' => 'mary'})
      # @return [Integer] return the offset for next append.
      # @yield [HTTP::StreamWriter] same as {#put_object}
      def append_object(key, pos, opts = {}, &block)
        args = opts.dup

        file = args[:file]
        args[:content_type] ||= get_content_type(file) if file
        args[:content_type] ||= get_content_type(key)

        if file
          next_pos = @protocol.append_object(name, key, pos, args) do |sw|
            File.open(File.expand_path(file), 'rb') do |f|
              sw << f.read(Protocol::STREAM_CHUNK_SIZE) until f.eof?
            end
          end
        else
          next_pos = @protocol.append_object(name, key, pos, args, &block)
        end

        next_pos
      end

      # copy an object in the bucket to another one.
      # @param source [String] source object name
      # @param dest [String] target object name
      # @param opts [Hash] options 
      # @option opts [String] :src_bucket source object's bucket. By default it's same as the target object's bucket
      #  Source Bucket and target bucket must belong to the same region.
      # @option opts [String] :acl target object's ACL property. Default is private.
      # @option opts [String] :meta_directive specifies if copying the metadata from source object as well.
      #  Default is {OSS::MetaDirective::COPY}：means it copies the metadata.
      # @option opts [Hash] :metas Sets object's meta，which is stored with the object content.
      #  {#get_object} could return these metadata.
      #  Its key is case insensitive. For example: { 'year' => '2015'}. 
      #  if meta_directive is {OSS::MetaDirective::COPY}, then this opt will be ignored.
      # @option opts [Hash] :condition specifies conditions to copy the object.
      #  It's same as {#get_object}.
      # @return [Hash] target object's information.
      #  * :etag [String] Target object's ETag
      #  * :last_modified [Time] Target object last modified time.
      def copy_object(source, dest, opts = {})
        args = opts.dup

        args[:content_type] ||= get_content_type(dest)
        @protocol.copy_object(name, source, dest, args)
      end

      # Deletes an object
      # @param key [String] Object name
      def delete_object(key)
        @protocol.delete_object(name, key)
      end

      # deletes multiple objects
      # @param keys [Array<String>] Object names' set
      # @param opts [Hash] options for deleting objects
      # @option opts [Boolean] :quiet specifies if prevent server returning objects status. 
      #  Default is false which means returns all the objects' deletion status.
      # @return [Array<String>] return deleted objects list. If quiet is specified, return [].
      def batch_delete_objects(keys, opts = {})
        @protocol.batch_delete_objects(
          name, keys, opts.merge(encoding: KeyEncoding::URL))
      end

      # Sets object ACL
      # @param key [String] Object name
      # @param acl [String] Object's {OSS::ACL ACL}
      def set_object_acl(key, acl)
        @protocol.put_object_acl(name, key, acl)
      end

      # Gets object ACL
      # @param key [String] Object name
      # @return [String] object的{OSS::ACL ACL}
      def get_object_acl(key)
        @protocol.get_object_acl(name, key)
      end

      # Gets object's CORS rule
      # @param key [String] Object name
      # @return [OSS::CORSRule]
      def get_object_cors(key)
        @protocol.get_object_cors(name, key)
      end

      ##
      # APIs about upload with checkpoint (a.k. resumable upload)
      #

      # Uploads a local file to the bucket with checkpoint support. 
      # The file will be upload in parts and only after all parts upload succeed, the file upload is complete and available for access.
      # 
      # @param key [String] Object key
      # @param file [String] the local file path
      # @param opts [Hash] options for upload file
      # @option opts [String] :content_type content-type
      #  Content-Type，default is application/octet-stream
      # @option opts [Hash] :metas Sets object meta which is user's custom attributes. They're stored with the object content.
      #  The meta information is returned in {#get_object}'s response.
      #  The keys in meta are case insensitive. For example：{ 'year' => '2015' }
      # @option opts [Integer] :part_size Part size
      #  Default is 10 MB. The max part count is 10,000.
      # @option opts [String] :cpt_file the checkpoint file path (local) If the cpt_file does not exist, it will create a 
      # default cpt file (named as $file.cpt, $file is the file name to upload) of the current file's folder.
      # The cpt file has the upload progress information and thus if the upload failed, the next upload would resume 
      # the upload according to the checkpoint.
      # @option opts [Boolean] :disable_cpt flag of disabling checkpoint function. If true, the checkpoint function is disabled and cpt_file is ignored.
      # @option opts [Callback] :callback specifies the callback information after a successful upload.
      #  After the file is uploaded, OSS could send a POST request to the specified URL and other information in the callback parameter.
      # @option opts [Hash] :headers specifies the HTTP headers in the request, it's case insensitive.
      #  The values could overwrite the one set by `:content_type` and `:metas`.
      # @yield [Float] If the block is specified, the upload progress will be stored in the block.
      #  The progress is the number between 0 to 1.
      # @raise [CheckpointBrokenError] If the cp file is corrupted, the CheckpointBrokenError is thrown.
      # @raise [FileInconsistentErro] If the specified file does not match the one in cpt, the eFileInconsistentError is thrown.
      # @raise [CallbackError] If the file is uploaded but the callback call fails, CallbackError is thrown
      # @example
      #   bucket.resumable_upload('my-object', '/tmp/x') do |p|
      #     puts "Progress: #{(p * 100).round(2)} %"
      #   end
      # @example specifies Callback
      #   callback = Aliyun::OSS::Callback.new(
      #     url: 'http://10.101.168.94:1234/callback',
      #     query: {user: 'put_object'},
      #     body: 'bucket=${bucket}&object=${object}'
      #   )
      #
      #   bucket.resumable_upload('files/hello', '/tmp/x', callback: callback)
      # @note If `:callback` is specified, then it's possible that file upload succeeds but callback fails.
      #  Then in this case the {OSS::CallbackError} is thrown. User could opt to catch this exception to ignore the callback failure.
      def resumable_upload(key, file, opts = {}, &block)
        args = opts.dup

        args[:content_type] ||= get_content_type(file)
        args[:content_type] ||= get_content_type(key)
        cpt_file = args[:cpt_file] || get_cpt_file(file)

        Multipart::Upload.new(
          @protocol, options: args,
          progress: block,
          object: key, bucket: name, creation_time: Time.now,
          file: File.expand_path(file), cpt_file: cpt_file
        ).run
      end

      # Download bucket to the local file, with checkpoint supported. The specified object could be downloaded in parts.
      # And only after all the parts are downloaded, the whole object download is complete.
      # For every downloaded part, it will be stored in the file's folder with name pattern file.part.N.
      # Once the download succceeds, all these parts will be merged to the final file and then get deleted.
      # @param key [String] Object key
      # @param file [String] the local file path
      # @param opts [Hash] options for downloading the file.
      # @option opts [Integer] :part_size part size. Default is 10MB. Max part count is 100 and thus the part size could be
      # bigger if the file is more than 1GB.
      # @option opts [String] :cpt_file checkpoint file. If the cpt file does not exist, it will create one named as $file.cpt----$file is the target file name.
      #  If the cpt file exists, then the download will resume from the last download according to the checkpoint.
      # @option opts [Boolean] :disable_cpt flag of disabling checkpoint. If true, then it's disabled and cpt_file is ignored.
      # @option opts [Hash] :condition the conditions to download the object, same as {#get_object}.
      # @option opts [Hash] :headers specifies the http headers (case insensitive). They may overwrite the values set by 'condition'.
      # @option opts [Hash] :rewrite specifies the headers to ask OSS return them in the response. Check out {#get_object} for the detail.
      # @yield [Float] If the block is specified, the download progress is stored in block, which is the number between 0 to 1.
      # @raise [CheckpointBrokenError] If the cpt file is corrupted, the error is thrown.
      # @raise [ObjectInconsistentError] If the object's ETag does not match the cpt file's one, the error is thrown.
      # @raise [PartMissingError] If the download parts file do not exist, the error is thrown.
      # @raise [PartInconsistentError] If the downloaded parts file's MD5 does not match with the CPT file, the error is thrown.
      # @note The downloaded parts will be stored in the same folder of the target fiel with name as file.part.N.
      # @example
      #   bucket.resumable_download('my-object', '/tmp/x') do |p|
      #     puts "Progress: #{(p * 100).round(2)} %"
      #   end
      def resumable_download(key, file, opts = {}, &block)
        args = opts.dup

        args[:content_type] ||= get_content_type(file)
        args[:content_type] ||= get_content_type(key)
        cpt_file = args[:cpt_file] || get_cpt_file(file)

        Multipart::Download.new(
          @protocol, options: args,
          progress: block,
          object: key, bucket: name, creation_time: Time.now,
          file: File.expand_path(file), cpt_file: cpt_file
        ).run
      end

      # Lists all ongoing multipart upload requests, not includes completed or aborted one.
      # @param [Hash] opts options
      # @option opts [String] :key_marker object key marker. Its behavior depends on if id_marker is set:
      #  1. If :id_marker is not specifeid，then returned objects' key are all larger than :key_marker in lexicrographic order.
      #  2. If :id_marker is specified, then the returned objects' key are larger than :key_marker or same as the :key_marker but the upload id is 
      #      bigger thant he :id_marker.
      # @option opts [String] :id_marker upload id marker. See the detail in :key_marker.
      # @option opts [String] :prefix if the prefix is specified, only return the uploads whose target object key has the specified prefix.
      # @return [Enumerator<Multipart::Transaction>] Every element represents an upload request.
      # @example
      #   key_marker = 1, id_marker = null
      #   # return <2, 0>, <2, 1>, <3, 0> ...
      #   key_marker = 1, id_marker = 5
      #   # return <1, 6>, <1, 7>, <2, 0>, <3, 0> ...
      def list_uploads(opts = {})
        Iterator::Uploads.new(
          @protocol, name, opts.merge(encoding: KeyEncoding::URL)).to_enum
      end

      # Cancels the multipart upload request, to clear all parts data uploaded.
      # A successful cancel will clear all uploaded parts data of the upload.
      # @param [String] upload_id uplaod request Id. It could be retrieved from {#list_uploads}
      # @param [String] key Object key.
      def abort_upload(upload_id, key)
        @protocol.abort_multipart_upload(name, key, upload_id)
      end

      # Gets bucket's URL
      # @return [String] Bucket URL
      def bucket_url
        @protocol.get_request_url(name)
      end

      # Gets object's URL
      # @param [String] key Object key
      # @param [Boolean] sign flag of signing the url. Default is true
      # @param [Fixnum] expiry URL's expiration time in seconds. Default is 60 seconds.
      # @return [String] return the object's URL which could be used for accessing the object directly.
      def object_url(key, sign = true, expiry = 60)
        url = @protocol.get_request_url(name, key)
        return url unless sign

        expires = Time.now.to_i + expiry
        query = {
          'Expires' => expires.to_s,
          'OSSAccessKeyId' => CGI.escape(access_key_id)
        }

        sub_res = []
        if @protocol.get_sts_token
          sub_res << "security-token=#{@protocol.get_sts_token}"
          query['security-token'] = CGI.escape(@protocol.get_sts_token)
        end

        resource = "/#{name}/#{key}"
        unless sub_res.empty?
          resource << (resource.include?('?') ? "&#{sub_res.join('&')}" : "?#{sub_res.join('&')}")
        end

        string_to_sign = "" <<
                         "GET\n" << # method
                         "\n" <<    # Content-MD5
                         "\n" <<    # Content-Type
                         "#{expires}\n" <<
                         "#{resource}"

        signature = sign(string_to_sign)
        query_string =
          query.merge('Signature' => CGI.escape(signature))
          .map { |k, v| "#{k}=#{v}" }.join('&')

        link_char = url.include?('?') ? '&' : '?'
        [url, query_string].join(link_char)
      end

      # gets the user's ACCESS_KEY_ID
      # @return [String] gets the user's ACCESS_KEY_ID
      def access_key_id
        @protocol.get_access_key_id
      end

      # Sign the content with ACCESS_KEY_SECRET
      # @param [String] string_to_sign the content to sign
      # @return [String] the signature
      def sign(string_to_sign)
        @protocol.sign(string_to_sign)
      end

      # Get the download crc status
      # @return true(download crc enable) or false(download crc disable)
      def download_crc_enable
        @protocol.download_crc_enable
      end

      # Get the upload crc status
      # @return true(upload crc enable) or false(upload crc disable)
      def upload_crc_enable
        @protocol.upload_crc_enable
      end

      private
      # Infer the file's content type using MIME::Types
      # @param file [String] the file path
      # @return [String] the infered content type or nil if it fails
      #  to infer the content type
      def get_content_type(file)
        t = MIME::Types.of(file)
        t.first.content_type unless t.empty?
      end

      # Get the checkpoint file path for file
      # @param file [String] the file path
      # @return [String] the checkpoint file path
      def get_cpt_file(file)
        "#{File.expand_path(file)}.cpt"
      end
    end # Bucket
  end # OSS
end # Aliyun
