# -*- encoding: utf-8 -*-

module Aliyun
  module OSS
    ##
    # Bucket是用户的bucket相关的操作的client，主要包括三部分功能：
    # 1. bucket相关：创建、删除bucket，设置bucket的属性（acl, logging,
    #    website, etc）
    # 2. object相关：上传、下载、追加、拷贝object等
    # 3. multipart相关：断点续传、断点续载
    class Bucket

      include Struct::Base

      attrs :name, :location, :creation_time

      ### Bucket相关的API ###

      # 创建一个bucket
      # @param opts [Hash] 创建Bucket的属性（可选）
      # @option opts [:location] [String] 指定bucket所在的区域，默认为oss-cn-hangzhou
      def create!(opts = {})
        Protocol.create_bucket(name, opts)
      end

      # 删除一个bucket
      # @note 如果要删除的Bucket不为空（包含有object），则删除会失败
      def delete!
        Protocol.delete_bucket(name)
      end

      # 获取Bucket的ACL
      # @return [String] Bucket的{OSS::ACL ACL}
      def acl
        Protocol.get_bucket_acl(name)
      end

      # 设置Bucket的ACL
      # @param acl [String] Bucket的{OSS::ACL ACL}
      def acl=(acl)
        Protocol.update_bucket_acl(name, acl)
      end

      # 获取Bucket的logging配置
      # @return [Hash] Bucket的logging配置。见{#logging=}
      def logging
        Protocol.get_bucket_logging(name)
      end

      # 设置Bucket的logging配置
      # @param opts [Hash] logging配置
      # @option opts [Boolean] [:enable] 是否开启logging
      # @option opts [String] [:target_bucket] 用于存放日志object的bucket名字
      # @option opts [String] [:prefix] 开启日志的object的前缀，若不指
      #  定则对bucket下的所有object都开启
      # @note 如果opts为空，则会删除这个bucket上的logging配置
      def logging=(opts)
        if opts.empty?
          Protocol.delete_bucket_logging(name)
        else
          Protocol.update_bucket_logging(name, opts)
        end
      end

      # 获取Bucket的website配置
      # @return [Hash] Bucket的website配置。See #website=
      def website
        Protocol.get_bucket_website(name)
      end

      # 设置Bucket的website配置
      # @param opts [Hash] website配置
      # @option opts [String] :index 网站首页的后缀，如index.html
      # @option opts [String] :error 网站错误页面的object名字，如
      #  error.html
      # @note 如果opts为空，则会删除这个bucket上的website配置
      def website=(opts)
        if opts.empty?
          Protocol.delete_bucket_website(name)
        else
          Protocol.update_bucket_website(name, opts)
        end
      end

      # 获取Bucket的Referer配置
      # @return [Hash] Bucket的Referer配置。See #referer=
      def referer
        Protocol.get_bucket_referer(name)
      end

      # 设置Bucket的Referer配置
      # @param opts [Hash] Referer配置
      # @option opts [Boolean] [:allow_empty] 设置是否允许Referer为空
      #  的请求访问Bucket
      # @option opts [Array<String>] [:referers] 设置允许访问Bucket的
      #  请求的Referer白名单
      # @note 如果opts为空，则会删除这个bucket上的referer配置
      def referer=(opts)
        Protocol.update_bucket_referer(name, opts)
      end

      # 获取Bucket的生命周期配置
      # @return [Array<OSS::LifeCycleRule>] Bucket的生命周期规则
      def lifecycle
        Protocol.get_bucket_lifecycle(name)
      end

      # 设置Bucket的生命周期配置
      # @param rules [Array<OSS::LifeCycleRule>] 生命
      #  周期配置规则
      # @see OSS::LifeCycleRule 查看如何设置生命周期规则
      # @note 如果rules为空，则会删除这个bucket上的lifecycle配置
      def lifecycle=(rules)
        if rules.empty?
          Protocol.delete_bucket_lifecycle(name)
        else
          Protocol.update_bucket_lifecycle(name, rules)
        end
      end

      # 获取Bucket的跨域资源共享(CORS)的规则
      # @return [Array<OSS::CORSRule>] Bucket的CORS规则
      def cors
        Protocol.get_bucket_cors(name)
      end

      # 设置Bucket的跨域资源共享(CORS)的规则
      # @param rules [Array<OSS::CORSRule>] CORS规则
      # @note 如果rules为空，则会删除这个bucket上的CORS配置
      def cors=(rules)
        if rules.empty?
          Protocol.delete_bucket_cors(name)
        else
          Protocol.set_bucket_cors(name, rules)
        end
      end

      ### Object相关的API ###


      # 列出bucket中的object
      # @param opts [Hash] 查询选项
      # @option opts [String] :prefix 返回的object的前缀，如果设置则只
      #  返回那些名字以它为前缀的object
      # @option opts [String] :delimiter 用于获取公共前缀的分隔符，从
      #  前缀后面开始到第一个分隔符出现的位置之前的字符，作为公共前缀。
      # @example
      #  假设我们有如下objects:
      #     /foo/bar/obj1
      #     /foo/bar/obj2
      #     ...
      #     /foo/bar/obj9999999
      #     /foo/xxx/
      #  用'foo/'作为前缀, '/'作为分隔符, 则得到的公共前缀是：
      #  '/foo/bar/', '/foo/xxx/'。它们恰好就是目录'/foo/'下的所有子目
      #  录。用delimiter获取公共前缀的方法避免了查询当前bucket下的所有
      #   object（可能数量巨大），是用于模拟目录结构的常用做法。
      # @option opts [String] :encoding 指定返回的响应中object名字的编
      #  码方法，目前只支持{OSS::KeyEncoding::URL}编码方式。
      # @return [Enumerator<Object>] 其中Object可能是{OSS::Object}，也
      #  可能是{String}，此时它是一个公共前缀
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
        Iterator::Objects.new(name, opts).to_enum
      end

      # 向Bucket中上传一个object
      # @param key [String] Object的名字
      # @param opts [Hash] 上传object时的选项（可选）
      # @option opts [String] :file 设置所上传的文件
      # @option opts [String] :content_type 设置所上传的内容的
      #  Content-Type，默认是application/octet-stream
      # @option opts [Hash] :metas 设置object的meta，这是一些用户自定
      #  义的属性，它们会和object一起存储，在{#get_object_meta}的时候会
      #  返回这些meta。属性的key不区分大小写。例如：{ 'year' => '2015' }
      # @yield [HTTP::StreamWriter] 如果调
      #  用的时候传递了block，则写入到object的数据由block指定
      # @example 流式上传数据
      #   put_object('x'){ |stream| 100.times{ |i| stream << i.to_s } }
      #   put_object('x'){ |stream| stream << get_data }
      # @example 上传文件
      #   put_object('x', :file => '/tmp/x')
      # @example 指定Content-Type和metas
      #   put_object('x', :file => '/tmp/x', :content_type => 'text/html',
      #              :metas => {'year' => '2015', 'people' => 'mary'})
      # @note 采用streaming的方式时，提供的数据必须是有结束标记的数据。
      #  因为put_object会不断地从StreamWriter中读取数据上传到OSS，直到
      #  它读到的数据为nil停止。
      # @note 如果opts中指定了:file，则block会被忽略
      def put_object(key, opts = {}, &block)
        file = opts[:file]
        if file
          opts[:content_type] = get_content_type(file)

          Protocol.put_object(name, key, opts) do |sw|
            File.open(File.expand_path(file)) do |f|
              sw << f.read(Protocol::STREAM_CHUNK_SIZE) until f.eof?
            end
          end
        else
          Protocol.put_object(name, key, opts, &block)
        end
      end

      # 从Bucket中下载一个object
      # @param key [String] Object的名字
      # @param opts [Hash] 下载Object的选项（可选）
      # @option opts [Array<Integer>] :range 指定下载object的部分数据，
      #  range应只包含两个数字，表示一个*左开右闭*的bytes range
      # @option opts [String] :file 指定将下载的object写入到文件中
      # @option opts [Hash] :condition 指定下载object需要满足的条件
      #   * :if_modified_since (Time) 指定如果object的修改时间晚于这个值，则下载
      #   * :if_unmodified_since (Time) 指定如果object从这个时间后再无修改，则下载
      #   * :if_match_etag (String) 指定如果object的etag等于这个值，则下载
      #   * :if_unmatch_etag (String) 指定如果object的etag不等于这个值，则下载
      # @option opts [Hash] :rewrite 指定下载object时Server端返回的响应头部字段的值
      #   * :content_type (String) 指定返回的响应中Content-Type的值
      #   * :content_language (String) 指定返回的响应中Content-Language的值
      #   * :expires (Time) 指定返回的响应中Expires的值
      #   * :cache_control (String) 指定返回的响应中Cache-Control的值
      #   * :content_disposition (String) 指定返回的响应中Content-Disposition的值
      #   * :content_encoding (String) 指定返回的响应中Content-Encoding的值
      # @return [OSS::Object] 返回Object对象
      # @yield [String] 如果调用的时候传递了block，则获取到的object的数据交由block处理
      # @example 流式下载文件
      #   get_object('x'){ |chunk| handle_chunk_data(chunk) }
      # @example 下载到本地文件
      #   get_object('x', :file => '/tmp/x')
      # @example 指定检查条件
      #   get_object('x', :file => '/tmp/x', :condition => {:if_match_etag => 'etag'})
      # @example 指定重写响应的header信息
      #   get_object('x', :file => '/tmp/x', :rewrite => {:content_type => 'text/html'})
      # @note 注意：如果opts中指定了:file，则block会被忽略
      def get_object(key, opts = {}, &block)
        obj = nil
        file = opts[:file]
        if file
          File.open(File.expand_path(file), 'w') do |f|
            obj = Protocol.get_object(name, key, opts) do |chunk|
              f.write(chunk)
            end
          end
        else
          obj = Protocol.get_object(name, key, opts, &block)
        end

        obj
      end

      # 获取Object的meta而不下载Object内容
      # @param key [String] Object的名字
      # @param opts [Hash] 下载Object的选项（可选）
      # @option opts [Hash] :condition 指定下载object需要满足的条件，
      #  同{#get_object}
      # @return [OSS::Object] 返回Object对象
      def get_object_meta(key, opts = {})
        Protocol.get_object_meta(name, key, opts)
      end

      # 判断一个object是否存在
      # @param key [String] Object的名字
      # @return [Boolean] 如果Object存在返回true，否则返回false
      def object_exists?(key)
        begin
          get_object_meta(key)
          return true
        rescue ServerError => e
          return false if e.http_code == 404
          raise e
        end

        false
      end

      alias :object_exist? :object_exists?

      # 向Bucket中的object追加内容。如果object不存在，则创建一个
      # Appendable Object。
      # @param key [String] Object的名字
      # @param opts [Hash] 上传object时的选项（可选）
      # @option opts [String] :file 指定追加的内容从文件中读取
      # @option opts [String] :content_type 设置所上传的内容的
      #  Content-Type，默认是application/octet-stream
      # @option opts [Hash] :metas 设置object的meta，这是一些用户自定
      #  义的属性，它们会和object一起存储，在{#get_object_meta}的时候会
      #  返回这些meta。属性的key不区分大小写。例如：{ 'year' => '2015' }
      # @example 流式上传数据
      #   pos = append_object('x', 0){ |stream| 100.times{ |i| stream << i.to_s } }
      #   append_object('x', pos){ |stream| stream << get_data }
      # @example 上传文件
      #   append_object('x', 0, :file => '/tmp/x')
      # @example 指定Content-Type和metas
      #   append_object('x', 0, :file => '/tmp/x', :content_type => 'text/html',
      #                 :metas => {'year' => '2015', 'people' => 'mary'})
      # @return [Integer] 返回下次append的位置
      # @yield [HTTP::StreamWriter] 同 {#put_object}
      def append_object(key, pos, opts = {}, &block)
        next_pos = -1
        file = opts[:file]
        if file
          opts[:content_type] = get_content_type(file)

          next_pos = Protocol.append_object(name, key, pos, opts) do |sw|
            File.open(File.expand_path(file)) do |f|
              sw << f.read(Protocol::STREAM_CHUNK_SIZE) until f.eof?
            end
          end
        else
          next_pos = Protocol.append_object(name, key, pos, opts, &block)
        end

        next_pos
      end

      # 将Bucket中的一个object拷贝成另外一个object
      # @param source [String] 源object名字
      # @param dest [String] 目标object名字
      # @param opts [Hash] 拷贝object时的选项（可选）
      # @option opts [String] :acl 目标文件的acl属性，默认为private
      # @option opts [String] :meta_directive 指定是否拷贝源object的
      #  meta信息，默认为{OSS::MetaDirective::COPY}：即拷贝object的时
      #  候也拷贝meta信息。
      # @option opts [Hash] :metas 设置object的meta，这是一些用户自定
      #  义的属性，它们会和object一起存储，在{#get_object_meta}的时候会
      #  返回这些meta。属性的key不区分大小写。例如：{ 'year' => '2015'
      #  }。如果:meta_directive为{OSS::MetaDirective::COPY}，则:metas
      #  会被忽略。
      # @option opts [Hash] :condition 指定拷贝object需要满足的条件，
      #  同 {#get_object}
      def copy_object(source, dest, opts = {})
        Protocol.copy_object(name, source, dest, opts)
      end

      # 删除一个object
      # @param key [String] Object的名字
      def delete_object(key)
        Protocol.delete_object(name, key)
      end

      # 批量删除object
      # @param keys [Array<String>] Object的名字集合
      # @param opts [Hash] 删除object的选项（可选）
      # @option opts [Boolean] :quiet 指定是否允许Server返回成功删除的
      #  object
      # @option opts [String] :encoding 指定Server返回的成功删除的
      #  object的名字的编码方式，目前只支持{OSS::KeyEncoding::URL}
      # @return [Array<String>] 成功删除的object的名字，如果指定
      #  了:quiet参数，则返回[]
      def batch_delete_objects(keys, opts = {})
        Protocol.batch_delete_objects(name, keys, opts)
      end

      # 设置object的ACL
      # @param key [String] Object的名字
      # @param acl [String] Object的{OSS::ACL ACL}
      def update_object_acl(key, acl)
        Protocol.update_object_acl(name, key, acl)
      end

      # 获取object的ACL
      # @param key [String] Object的名字
      # @return [String] object的{OSS::ACL ACL}
      def get_object_acl(key)
        Protocol.get_object_acl(name, key)
      end

      # 获取object的CORS规则
      # @param key [String] Object的名字
      # @return [OSS::CORSRule]
      def get_object_cors(key)
        Protocol.get_object_cors(name, key)
      end

      ##
      # 断点续传相关的API
      #

      # 上传一个本地文件到bucket中的一个object，支持断点续传。指定的文
      # 件会被分成多个分片进行上传，只有所有分片都上传成功整个文件才
      # 上传成功。
      # @param key [String] Object的名字
      # @param file [String] 本地文件的路径
      # @param opts [Hash] 上传文件的可选项
      # @option opts [String] :content_type 设置所上传的内容的
      #  Content-Type，默认是application/octet-stream
      # @option opts [Hash] :metas 设置object的meta，这是一些用户自定
      #  义的属性，它们会和object一起存储，在{#get_object_meta}的时候会
      #  返回这些meta。属性的key不区分大小写。例如：{ 'year' => '2015' }
      # @option opts [Integer] :part_size 设置分片上传时每个分片的大小，
      #  默认为1 MB。断点上传最多允许10000个分片，如果文件大于10000个
      #  分片的大小，则每个分片的大小会大于1MB。
      # @option opts [String] :cpt_file 断点续传的checkpoint文件，如果
      #  指定的cpt文件不存在，则会在file所在目录创建一个默认的cpt文件，
      #  命名方式为：file.cpt，其中file是用户要上传的文件。在上传的过
      #  程中会不断更新此文件，成功完成上传后会删除此文件；如果指定的
      #  cpt文件已存在，则从cpt文件中记录的点继续上传。
      # @option opts [Boolean] :disable_cpt 是否禁用checkpoint功能，如
      #  果设置为true，则在上传的过程中不会写checkpoint文件，这意味着
      #  上传失败后不能断点续传，而只能重新上传整个文件。如果这个值为
      #  true，则:cpt_file会被忽略。
      # @raise [CheckpointBrokenError] 如果cpt文件被损坏，则抛出此错误
      # @raise [FileInconsistentError] 如果指定的文件与cpt中记录的不一
      #  致，则抛出此错误
      def resumable_upload(key, file, opts = {})
        unless cpt_file = opts[:cpt_file]
          cpt_file = get_cpt_file(file)
        end

        Multipart::Upload.new(
          :options => opts,
          :object => key,
          :bucket => name,
          :creation_time => Time.now,
          :file => File.expand_path(file),
          :cpt_file => cpt_file
        ).run
      end

      # 下载bucket中的一个object到本地文件，支持断点续传。指定的object
      # 会被分成多个分片进行下载，只有所有的分片都下载成功整个object才
      # 下载成功。对于每个下载的分片，会在file所在目录建立一个临时文件
      # file.part.N，下载成功后这些part文件会被合并成最后的file然后删
      # 除。
      # @param key [String] Object的名字
      # @param file [String] 本地文件的路径
      # @param opts [Hash] 下载文件的可选项
      # @option opts [Integer] :part_size 设置分片上传时每个分片的大小，
      #  默认为1 MB。断点下载最多允许100个分片，如果文件大于100个分片，
      #  则每个分片的大小会大于1MB
      # @option opts [String] :cpt_file 断点续传的checkpoint文件，如果
      #  指定的cpt文件不存在，则会在file所在目录创建一个默认的cpt文件，
      #  命名方式为：file.cpt，其中file是用户要下载的文件名。在下载的过
      #  程中会不断更新此文件，成功完成下载后会删除此文件；如果指定的
      #  cpt文件已存在，则从cpt文件中记录的点继续下载。
      # @option opts [Boolean] :disable_cpt 是否禁用checkpoint功能，如
      #  果设置为true，则在下载的过程中不会写checkpoint文件，这意味着
      #  下载失败后不能断点续传，而只能重新下载整个文件。如果这个值为true，
      #  则:cpt_file会被忽略。
      # @option opts [Hash] :condition 指定下载object需要满足的条件，
      #  同 {#get_object}
      # @option opts [Hash] :rewrite 指定下载object时Server端返回的响
      #  应头部字段的值，同 {#get_object}
      # @raise [CheckpointBrokenError] 如果cpt文件被损坏，则抛出此错误
      # @raise [ObjectInconsistentError] 如果指定的object的etag与cpt文
      #  件中记录的不一致，则抛出错误
      # @raise [PartMissingError] 如果已下载的部分(.part文件)找不到，
      #  则抛出此错误
      # @raise [PartInconsistentError] 如果已下载的部分(.part文件)的
      #  MD5值与cpt文件记录的不一致，则抛出此错误
      # @note 已经下载的部分会在file所在的目录创建.part文件，命名方式
      #  为file.part.N
      def resumable_download(key, file, opts = {})
        unless cpt_file = opts[:cpt_file]
          cpt_file = get_cpt_file(file)
        end

        Multipart::Download.new(
          :options => opts,
          :object => key,
          :bucket => name,
          :creation_time => Time.now,
          :file => File.expand_path(file),
          :cpt_file => cpt_file
        ).run
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
