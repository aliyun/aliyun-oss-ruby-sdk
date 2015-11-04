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

          body = HTTP.do_request('GET', {}, {:query => params})
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

          HTTP.do_request('PUT', {:bucket => name}, {:body => body})

          logger.info("Done create bucket")
        end

        # 删除一个bucket
        # [name] bucket的名字
        def delete_bucket(name)
          logger.info("Begin delete bucket: #{name}")

          HTTP.do_request('DELETE', {:bucket => name})

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

          HTTP.do_request(
            'PUT',
            {:bucket => bucket_name, :object => object_name},
            {:body => HTTP::StreamReader.new(block)})

          logger.info('Done put object')
        end

        # 向名为bucket_name的bucket中添加一个object，名字为object_name，
        # object的内容从路径为file_path的文件读取
        # [bucket_name] bucket名字
        # [object_name] object名字
        # [file_path] 要读取的文件
        def put_object_from_file(bucket_name, object_name, file_path)
          logger.info("Begin put object from file: #{file_path}")

          put_object(bucket_name, object_name) do |content|
            content << File.read(file_path)
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
          HTTP.do_request(
            'POST',
            {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
            {:body => HTTP::StreamReader.new(block)})

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

          append_object(bucket_name, object_name, position) do |content|
            content << File.read(file_path)
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

          body = HTTP.do_request('GET', {:bucket => bucket_name}, {:query => params})

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

          HTTP.do_request(
            'GET', {
              :bucket => bucket_name,
              :object => object_name}) {|chunk| block.call(chunk)}

          logger.info("Done get object")
        end

        # 下载指定的bucket中的指定object，将object内容写入到文件中
        # [bucket_name] bucket的名字
        # [object_name] object的名字
        # [file_path] 写入object内容的文件名
        def get_object_to_file(bucket_name, object_name, file_path)
          logger.info("Begin get object to file, bucket: #{bucket_name}, object: #{object_name}, file: #{file_path}")

          get_object(bucket_name, object_name) do |chunk|
            File.open(file_path, 'w') do |f|
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

          body = HTTP.do_request(
            'PUT',
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

          HTTP.do_request(
            'DELETE', {:bucket => bucket_name, :object => object_name})

          logger.info("Done delete object")
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
