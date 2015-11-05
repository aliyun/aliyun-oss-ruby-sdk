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
        def list_bucket(opts = {})
          logger.info('Begin list bucket')

          params = {
            'prefix' => opts[:prefix],
            'marker' => opts[:marker],
            'max-keys' => opts[:limit]
          }.select {|k, v| v}

          _, body = HTTP.get( {}, {:query => params})
          doc = parse_xml(body)

          buckets = doc.css("Buckets Bucket").map do |node|
            name = get_node_text(node, "Name")
            location = get_node_text(node, "Location")
            creation_time = Time.parse(get_node_text(node, "CreationDate"))
            Bucket.new(name, location, creation_time)
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

        # 删除一个bucket
        # [name] bucket的名字
        def delete_bucket(name)
          logger.info("Begin delete bucket: #{name}")

          HTTP.delete({:bucket => name})

          logger.info("Done delete bucket")
        end

        # 向名为bucket_name的bucket中添加一个object，名字为object_name，
        # object的内容由block提供
        # [bucket_name] bucket名字
        # [object_name] object名字
        # [block] 提供object的内容
        def put_object(bucket_name, object_name, &block)
          raise ClientError.new('Missing block in put_object') unless block

          logger.info("Begin put object, bucket: #{bucket_name}, object:#{object_name}")

          HTTP.put(
            {:bucket => bucket_name, :object => object_name},
            {:body => HTTP::StreamPayload.new(block)})

          logger.info('Done put object')
        end

        # 向名为bucket_name的bucket中添加一个object，名字为object_name，
        # object的内容从路径为file_path的文件读取
        # [bucket_name] bucket名字
        # [object_name] object名字
        # [file_path] 要读取的文件
        def put_object_from_file(bucket_name, object_name, file_path)
          logger.info("Begin put object from file: #{file_path}")

          file = File.open(File.expand_path(file_path))
          put_object(bucket_name, object_name) do |content|
            content << file.read(STREAM_CHUNK_SIZE) unless file.eof?
          end

          logger.info('Done put object from file')
        end

        # 向名为bucket_name的bucket中名字为object_name的object追加内容，
        # object的内容由block提供，如果object不存在，则创建一个
        # Appendable Object。
        # [bucket_name] bucket名字
        # [object_name] object名字
        # [position] 追加的位置
        # [block] 提供object的内容
        # *注意：不能向Normal object追加内容*
        def append_object(bucket_name, object_name, position, &block)
          raise ClientError.new('Missing block in append_object') unless block

          logger.info("Begin append object, bucket: #{bucket_name}, object: #{object_name}, position: #{position}")

          sub_res = {'append' => nil, 'position' => position}
          HTTP.post(
            {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
            {:body => HTTP::StreamPayload.new(block)})

          logger.info('Done append object')
        end

        # 向名为bucket_name的bucket中名字为object_name的object追加内容，
        # object的内容从文件中读取，如果object不存在，则创建一个
        # Appendable Object。
        # [bucket_name] bucket名字
        # [object_name] object名字
        # [position] 追加的位置
        # [file_path] 要读取的文件
        # *注意：不能向Normal object追加内容*
        def append_object_from_file(bucket_name, object_name, position, file_path, &block)
          logger.info("Begin append object, bucket: #{bucket_name}, object: #{object_name}, position: #{position}, file: #{file_path}")

          file = File.open(File.expand_path(file_path))
          append_object(bucket_name, object_name, position) do |content|
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
        def list_object(bucket_name, opts = {})
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
          objects = doc.css("Contents").map do |node|
            Object.new(
              :key => get_node_text(node, "Key"),
              :type => get_node_text(node, "Type"),
              :size => get_node_text(node, "Size").to_i,
              :etag => get_node_text(node, "ETag"),
              :last_modified =>
              get_node_text(node, "LastModified") {|x| Time.parse(x)})
          end

          more = Hash[{
                        :prefix => 'Prefix',
                        :delimiter => 'Delimiter',
                        :limit => 'MaxKeys',
                        :marker => 'Marker',
                        :next_marker => 'NextMarker',
                        :truncated => 'IsTruncated',
                        :encoding => 'encoding-type'
                      }.map do |k, v|
                        [k, get_node_text(doc.root, v)]
                      end].select {|k, v| v}

          more[:limit] = more[:limit].to_i if more[:limit]
          more[:truncated] = more[:truncated].to_bool if more[:truncated]

          common_prefixes = []
          doc.css("CommonPrefixes Prefix").map do |node|
            common_prefixes << node.text
          end
          more[:common_prefixes] = common_prefixes unless common_prefixes.empty?

          logger.info("Done list object")

          [objects, more]
        end

        # 下载指定的bucket中的指定object
        # [bucket_name] bucket的名字
        # [object_name] object的名字
        # [block] 处理object内容
        def get_object(bucket_name, object_name, &block)
          logger.info("Begin get object, bucket: #{bucket_name}, object: #{object_name}")

          HTTP.get({:bucket => bucket_name, :object => object_name}) do |chunk|
            block.call(chunk)
          end

          logger.info("Done get object")
        end

        # 下载指定的bucket中的指定object，将object内容写入到文件中
        # [bucket_name] bucket的名字
        # [object_name] object的名字
        # [file_path] 写入object内容的文件名
        def get_object_to_file(bucket_name, object_name, file_path)
          logger.info("Begin get object to file, bucket: #{bucket_name}, object: #{object_name}, file: #{file_path}")

          get_object(bucket_name, object_name) do |chunk|
            File.open(File.expand_path(file_path), 'w') do |f|
              f.write(chunk)
            end
          end

          logger.info("Done get object to file")
        end

        # 在一个bucket中拷贝一个object
        # [bucket_name] bucket的名字
        # [src_object_name] 源object的名字
        # [dst_object_name] 目标object的名字
        def copy_object(bucket_name, src_object_name, dst_object_name)
          logger.info("Begin copy object, bucket: #{bucket_name}, source object: #{src_object_name}, dest object: #{dst_object_name}")

          headers = {
            'x-oss-copy-source' =>
              HTTP.get_resource_path(bucket_name, src_object_name)
          }

          _, body = HTTP.put(
            {:bucket => bucket_name, :object => dst_object_name},
            {:headers => headers})

          doc = parse_xml(body)
          result = {
            :last_modified => get_node_text(
              doc.root, 'LastModified') {|x| Time.parse(x)},
            :etag => get_node_text(doc.root, 'ETag')
          }.select {|k, v| v}

          logger.info("Done copy object")

          result
        end

        # 删除指定的bucket中的指定object
        # [bucket_name] bucket的名字
        # [object_name] object的名字
        def delete_object(bucket_name, object_name)
          logger.info("Begin delete object, bucket: #{bucket_name}, object: #{object_name}")

          HTTP.delete({:bucket => bucket_name, :object => object_name})

          logger.info("Done delete object")
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
        # from an existent object as the part's content
        # [bucket_name] the bucket name
        # [object_name] the object name
        # [txn_id] the txn id
        # [part_no] the part number
        # [source_object] the source object to copy from
        def upload_part_from_object(bucket_name, object_name, txn_id, part_no, source_object)
          logger.debug("Begin upload part from object, bucket: #{bucket_name}, object: #{object_name}, txn id: #{txn_id}, part No: #{part_no}, source object: #{source_object}")

          headers = {
            'x-oss-copy-source' =>
              HTTP.get_resource_path(bucket_name, source_object)
          }
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
          logger.debug("Begin list_multipart_transactions, opts: #{opts}")

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
          txns = doc.css("Upload").map do |node|
            Multipart::Transaction.new(
              :id => get_node_text(node, "UploadId"),
              :object_key => get_node_text(node, "Key"),
              :creation_time =>
                get_node_text(node, "Initiated") {|t| Time.parse(t)})
          end

          more = Hash[{
                        :prefix => 'Prefix',
                        :delimiter => 'Delimiter',
                        :limit => 'MaxUploads',
                        :id_marker => 'UploadIdMarker',
                        :next_id_marker => 'NextUploadIdMarker',
                        :key_marker => 'KeyMarker',
                        :next_key_marker => 'NextKeyMarker',
                        :truncated => 'IsTruncated',
                        :encoding => 'encoding-type'
                      }.map do |k, v|
                        [k, get_node_text(doc.root, v)]
                      end].select {|k, v| v}

          more[:limit] = more[:limit].to_i if more[:limit]
          more[:truncated] = more[:truncated].to_bool if more[:truncated]

          logger.debug("Done list_multipart_transactions")

          [txns, more]
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

          more = Hash[{
                        :limit => 'MaxParts',
                        :marker => 'PartNumberMarker',
                        :next_marker => 'NextPartNumberMarker',
                        :truncated => 'IsTruncated',
                        :encoding => 'encoding-type'
                      }.map do |k, v|
                        [k, get_node_text(doc.root, v)]
                      end].select {|k, v| v}

          more[:limit] = more[:limit].to_i if more[:limit]
          more[:truncated] = more[:truncated].to_bool if more[:truncated]

          logger.debug("Done list_parts")

          [parts, more]
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

      end # self

    end # Protocol

  end # OSS
end # Aliyun
