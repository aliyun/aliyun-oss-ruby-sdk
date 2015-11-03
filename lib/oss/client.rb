# -*- encoding: utf-8 -*-

require 'rest-client'
require 'nokogiri'
require 'time'

module Aliyun
  module OSS

    ##
    # 用于操作OSS资源（bucket, object等）的client
    #
    class Client

      include Logging

      # 构造OSS client，参数：
      # [host] 服务的endpoint
      # [id] 服务的access key id
      # [key] 服务的access key secret
      def initialize(host, id, key)
        @host, @id, @key = host, id, key
      end

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

        body = send_request('GET', {}, {:query => params})
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
      # [attrs] 可选的参数：
      #     [:location] bucket所在的region，例如oss-cn-hangzhou
      def create_bucket(name, attrs)
        logger.info('Begin create bucket')

        location = attrs[:location]
        body = nil
        if location
          builder = Nokogiri::XML::Builder.new do |xml|
            xml.CreateBucketConfiguration {
              xml.LocationConstraint location
            }
          end
          body = builder.to_xml
        end

        send_request('PUT', {:bucket => name}, {:body => body})

        logger.info('Done create bucket')
      end

      # 删除一个bucket
      # [name] bucket的名字
      def delete_bucket(name)
        logger.info('Begin delete bucket: #{name}')

        send_request('DELETE', {:bucket => name})

        logger.info('Done delete bucket')
      end

      # 向名为bucket_name的bucket中添加一个object，名字为object_name，
      # object的内容由block提供
      # [bucket_name] bucket名字
      # [object_name] object名字
      # [block] 提供object的内容
      def put_object(bucket_name, object_name, &block)
        logger.info("Begin put object, bucket: #{bucket_name}, object:#{object_name}")

        content = ""
        block.call(content)
        send_request(
          'PUT',
          {:bucket => bucket_name, :object => object_name},
          {:body => content})

        logger.info('Done put object')
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
        logger.info("Begin append object, bucket: #{bucket_name}, object: #{object_name}, position: #{position}")

        content = ""
        block.call(content)
        sub_res = {'append' => nil, 'position' => position}
        send_request(
          'POST',
          {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
          {:body => content})

        logger.info('Done append object')
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

      # 列出指定的bucket中的所有object
      # [bucket_name] bucket的名字
      # [return] Object数组
      def list_object(bucket_name)
        logger.info("Begin list object, bucket: #{bucket_name}")

        body = send_request('GET', {:bucket => bucket_name})

        doc = parse_xml(body)
        objects = doc.css("Contents").map do |node|
          Object.new(
            :key => get_node_text(node, "Key"),
            :type => get_node_text(node, "Type"),
            :size => get_node_text(node, "Size").to_i,
            :etag => get_node_text(node, "ETag"),
            :last_modified => Time.parse(get_node_text(node, "LastModified")))
        end

        logger.info("Done list object")

        objects
      end

      # 下载指定的bucket中的指定object
      # [bucket_name] bucket的名字
      # [object_name] object的名字
      # [block] 处理object内容
      def get_object(bucket_name, object_name, &block)
        logger.info("Begin get object, bucket: #{bucket_name}, object: #{object_name}")

        body = send_request(
          'GET', {:bucket => bucket_name, :object => object_name})

        block.call(body)

        logger.info("Done get object")
      end

      # 下载指定的bucket中的指定object，将object内容写入到文件中
      # [bucket_name] bucket的名字
      # [object_name] object的名字
      # [file_path] 写入object内容的文件名
      def get_object_to_file(bucket_name, object_name, file_path)
        logger.info("Begin get object to file, bucket: #{bucket_name}, object: #{object_name}, file: #{file_path}")

        get_object(bucket_name, object_name) do |content|
          File.open(file_path, 'w') do |f|
            f.write(content)
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
          'x-oss-copy-source' => get_resource_path(bucket_name, src_object_name)
        }
        send_request(
          'PUT',
          {:bucket => bucket_name, :object => dst_object_name},
          {:headers => headers})

        logger.info("Done copy object")
      end

      # 删除指定的bucket中的指定object
      # [bucket_name] bucket的名字
      # [object_name] object的名字
      def delete_object(bucket_name, object_name)
        logger.info("Begin delete object, bucket: #{bucket_name}, object: #{object_name}")

        send_request(
          'DELETE', {:bucket => bucket_name, :object => object_name})

        logger.info("Done delete object")
      end

      private

      # 获取请求的URL，根据操作是否指定bucket和object，URL可能不同
      def get_request_url(bucket, object)
        url = ""
        url += "#{bucket}." if bucket
        url += @host
        url += "/#{object}" if object

        url
      end

      # 获取请求的资源路径
      def get_resource_path(bucket, object)
        if bucket
          res = "/#{bucket}/"
          res += "#{object}" if object
          res
        end
      end

      # 发送RESTful HTTP请求
      # [verb] HTTP动作: GET/PUT/POST/DELETE/HEAD
      # [resources] OSS相关的资源:
      #     [:bucket] bucket名字
      #     [:object] object名字
      #     [:sub_res] 子资源
      # [http_options] HTTP相关资源：
      #     [:headers] HTTP头
      #     [:body] HTTP body
      #     [:query] HTTP url参数
      def send_request(verb, resources = {}, http_options = {})
        bucket = resources[:bucket]
        object = resources[:object]
        sub_res = resources[:sub_res]

        headers = http_options[:headers] || {}
        headers['Date'] = Util.get_date
        headers['Content-Type'] = 'application/octet-stream'

        res = {
          :path => get_resource_path(bucket, object),
          :sub_res => sub_res,
        }
        signature = Util.get_signature(@key, verb, headers, res)
        auth = "OSS #{@id}:#{signature}"
        headers['Authorization']  = auth

        logger.debug("Send HTTP request, verb: #{verb}, resources: #{resources}, http options: #{http_options}")

        # from rest-client:
        # "Due to unfortunate choices in the original API, the params
        # used to populate the query string are actually taken out of
        # the headers hash."
        headers[:params] = (sub_res || {}).merge(http_options[:query] || {})

        r = RestClient::Request.execute(
          :method => verb,
          :url => get_request_url(bucket, object),
          :headers => headers,
          :payload => http_options[:body]) do |response, request, result, &block|

          if response.code >= 400
            e = Exception.new(response.code, response.body)
            logger.error(e.to_s)
            raise e
          else
            response.return!(request, result, &block)
          end
        end

        logger.debug("Received HTTP response, code: #{r.code}, headers: #{r.headers}, body: #{r.body}")

        r.body
      end

      # 将content解析成xml doc对象
      def parse_xml(content)
        doc = Nokogiri::XML(content) do |config|
          config.options |= Nokogiri::XML::ParseOptions::NOBLANKS
        end

        doc
      end

      # 获取节点下面的tag内容
      def get_node_text(node, tag)
        n = node.at_css(tag) if node
        n.text if n
      end

    end # Client

  end # OSS
end # Aliyun
