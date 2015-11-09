# -*- encoding: utf-8 -*-

module Aliyun
  module OSS
    ##
    # Bucket是一个存放Object的空间，用户可以从中添加、删除Object。
    # 可以在Bucket上设置ACL访问权限、logging、和Object的有效时间
    #
    class Bucket

      include Struct::Base

      attrs :name, :location, :creation_time

      ### Bucket相关的API ###

      # 创建一个bucket
      # @param name [String] Bucket名字
      # @param opts [Hash] 创建Bucket的属性（可选）
      # @option opts [:location] [String] 指定bucket所在的区域，默认为oss-cn-hangzhou
      # @see 可以到 http://aliyun.com 查看完整的区域列表
      def create(name, opts = {})
      end

      # 删除一个bucket
      # @param name [String] Bucket名字
      # @note 如果要删除的Bucket不为空（包含有object），则删除会失败
      def delete(name)
      end

      # 获取Bucket的ACL
      def acl
      end

      # 设置Bucket的ACL
      # @param acl [String] Bucket的ACL
      # @see Aliyun::OSS::Struct::ACL
      def acl=(acl)
      end

      # 获取Bucket的logging配置
      def logging
      end

      # 设置Bucket的logging配置
      # @param opts [Hash] logging配置
      # @option opts [Boolean] [:enable] 是否开启logging
      # @option opts [String] [:target_bucket] 用于存放日志object的bucket名字
      # @option opts [String] [:prefix] 开启日志的object的前缀，若不指
      # 定则对bucket下的所有object都开启
      def logging=(opts)
      end

      # 获取Bucket的website配置
      def website
      end

      # 设置Bucket的website配置
      # @param opts [Hash] website配置
      # @option opts [:index] 网站首页的后缀，如index.html
      # @option opts [:error] 网站错误页面的object名字，如error.html
      def website=(opts)
      end

      # 获取Bucket的Referer配置
      def referer
      end

      # 设置Bucket的Referer配置
      # @param opts [Hash] Referer配置
      # @option opts [Boolean] [:allow_empty] 设置是否允许Referer为空
      # 的请求访问Bucket
      # @option opts [Array<String>] [:referers] 设置允许访问Bucket的
      # 请求的Referer白名单
      # @see
      # https://docs.aliyun.com/?spm=5176.383663.9.2.73fUTr#/pub/oss/product-documentation/function&referer-white-list
      # 查看如何通过设置Referer来防盗链
      def referer=(opts)
      end

      # 获取Bucket的生命周期配置
      def lifecycle
      end

      # 设置Bucket的生命周期配置
      # @param rules [Array<Aliyun::OSS::Struct::LifeCycleRule>] 生命
      # 周期配置规则
      # @see Aliyun::OSS::Struct::LifeCycleRule 查看如何设置生命周期规
      # 则
      def lifecycle=(rules)
      end

      # 获取Bucket的跨域资源共享(CORS)的规则
      def cors
      end

      # 设置Bucket的跨域资源共享(CORS)的规则
      # @param rules [Array<Aliyun::OSS::Struct::CORSRule>] CORS规则
      # @see Aliyun::OSS::Struct::CORSRule 查看如何设置CORS规则
      def cors=(rules)
      end

      ### Object相关的API ###

      # 向Bucket中上传一个object
      # @param key [String] Object的名字
      # @param opts [Hash] 上传object时的选项（可选）
      # @option opts [String] :file 设置所上传的文件
      # @option opts [String] :content_type 设置所上传的内容的
      # Content-Type，默认是application/octet-stream
      # @yield stream writer [Aliyun::OSS::HTTP::StreamWriter] 如果调
      # 用的时候传递了block，则写入到object的数据由block指定
      # @example streaming put object
      #   chunk = get_chunk
      #   put_object('x') {|sw| sw.write(chunk)}
      # @note 采用streaming的方式时，提供的数据必须是有结束标记的数据。
      # 因为put_object会不断地从StreamWriter中读取数据上传到OSS，直到
      # 它读到的数据为nil停止。
      # @note 如果指定了opts[:file]，则block会被忽略
      def put_object(key, opts = {}, &block)
      end

      # 从Bucket中下载一个object
      # @param key [String] Object的名字
      # @param opts [Hash] 下载Object的选项（可选）
      #   * :range (Array<Integer>) 指定下载object的部分数据，range包含起始字节（包含）和结束字节（不包含），如[0, 200]表示下载object的前199个字节
      #   * :file (String) 指定将下载的object写入到文件中
      #   * :condition (Hash) 指定下载object需要满足的条件
      #     * :if_modified_since [Time] 指定如果object的修改时间晚于这个值，则下载
      #     * :if_unmodified_since (Time) 指定如果object从这个时间后再无修改，则下载
      #     * :if_match_etag (String) 指定如果object的etag等于这个值，则下载
      #     * :if_unmatch_etag (String) 指定如果object的etag不等于这个值，则下载
      #   * :rewrite (Hash) 指定下载object时Server端返回的响应头部字段的值
      #     * :content_type (String) 指定返回的响应中Content-Type的值
      #     * :content_language (String) 指定返回的响应中Content-Language的值
      #     * :expires (Time) 指定返回的响应中Expires的值
      #     * :cache_control (String) 指定返回的响应中Cache-Control的值
      #     * :content_disposition (String) 指定返回的响应中Content-Disposition的值
      #     * :content_encoding (String) 指定返回的响应中Content-Encoding的值
      # @yield data chunk [String] 如果调用的时候传递了block，则获取到的object的数据交由block处理
      # @example streaming get object
      #   file = open_file
      #   get_object('x') {|chunk| file.write(chunk) }
      # @note 注意：如果指定了opts[:file]，则block会被忽略
      def get_object(key, opts = {}, &block)
      end

      # 向Bucket中的object追加内容。如果object不存在，则创建一个
      # Appendable Object。
      # @param key [String] Object的名字
      # @param opts [Hash] 上传object时的选项（可选）
      # @option opts [String] :file 指定追加的内容从文件中读取
      # @option opts [String] :content_type 设置所上传的内容的
      # Content-Type，默认是application/octet-stream
      # @yield stream writer [Aliyun::OSS::HTTP::StreamWriter] 同 #put_object
      def append_object(key, opts = {}, &block)
      end

      # 将Bucket中的一个object拷贝成另外一个object
      # @param source [String] 源object名字
      # @param dest [String] 目标object名字
      # @param opts [Hash] 拷贝object时的选项（可选）
      # @option opts [String] :acl 目标文件的acl属性，默认为private
      # @option opts [String] :meta_directive 指定是否拷贝源object的
      # meta信息，转为为COPY：即拷贝object的时候也拷贝meta信息
      # @see Aliyun::OSS::Struct::MetaDirective
      # @option opts [Hash] :condition 指定拷贝object需要满足的条件，
      # 同 #get_object
      def copy_object(source, dest, opts = {})
      end

      # 删除一个object
      # @param key [String] Object的名字
      def delete_object(key)
      end

      # 批量删除object
      # @param keys [Array<String>] Object的名字集合
      # @param opts [Hash] 删除object的选项（可选）
      # @option opts [Boolean] :quiet 指定是否允许Server返回成功删除的
      # object
      # @option opts [String] :encoding 指定Server返回的成功删除的
      # object的名字的编码方式，目前只支持url
      # @see Aliyun::OSS::Struct::KeyEncoding
      def batch_delete_objects(keys, opts = {})
      end

      # 设置object的ACL
      # @param key [String] Object的名字
      # @param acl [String] Object的ACL
      # @see Aliyun::OSS::Struct::ACL
      def update_object_acl(key, acl)
      end

      # 获取object的ACL
      # @param key [String] Object的名字
      # @see Aliyun::OSS::Struct::ACL
      # @return [String] object的ACL
      def get_object_acl(key)
      end

      # 获取object的CORS规则
      # @param key [String] Object的名字
      # @see Aliyun::OSS::Struct::CORSRule
      # @return [Aliyun::OSS::Struct::CORSRule]
      def get_object_cors(key)
      end

      ##
      # 断点续传相关的API
      #

      # 上传一个本地文件到bucket中的一个object
      # @param key [String] Object的名字
      # @param file [String] 本地文件的路径
      # @param opts [Hash] 上传文件的可选项
      # @option opts [String] :content_type 设置所上传的内容的
      # Content-Type，默认是application/octet-stream
      # @option opts [String] :resume_token 断点续传的token文件，如果
      # 指定的token文件不存在，则开始一个新的上传，在上传的过程中会更
      # 新此文件；如果指定的token文件存在，则从token文件中记录的点继续
      # 上传。
      # @raise [Aliyun::OSS::FileInconsistentError] 如果指定的文件与
      # token中记录的不一致，则抛出此错误
      def upload_file(key, file, opts = {})
      end

      # 下载bucket中的一个object到本地文件
      # @param key [String] Object的名字
      # @param file [String] 本地文件的路径
      # @param opts [Hash] 下载文件的可选项
      # @option opts [Array<Integer>] :range 指定下载object的部分数据
      # @option opts [String] :resume_token 断点继续下载的token文件，
      # 如果指定的token文件不存在，则开始一个新的上传，在上传的过程中
      # 会更新此文件；如果指定的token文件存在，则从token文件中记录的点
      # 继续下载。
      # @option opts [Hash] :condition 指定下载object需要满足的条件，
      # 同 #get_object
      # @option opts [Hash] :rewrite 指定下载object时Server端返回的响
      # 应头部字段的值，同 #get_object
      # @raise [Aliyun::OSS::ObjectInconsistentError] 如果指定的object
      # 的etag与token中记录的不一致，则抛出错误
      # @raise [Aliyun::OSS::PartsMissingError] 如果已下载的部分(.part
      # 文件)找不到，则抛出此错误
      # @note 已经下载的部分会在file所在的目录创建.part文件，命名方式
      # 为file.part
      def download_file(key, file, opts = {})
      end

    end # Bucket
  end # OSS
end # Aliyun
