# -*- encoding: utf-8 -*-

module Aliyun
  module OSS
    ##
    # Bucket是一个存放Object的空间，用户可以从中添加、删除Object。
    # 可以在Bucket上设置ACL访问权限、logging、和Object的有效时间
    #
    class Bucket

      class ACL
        PUBLIC_READ_WRITE = "public-read-write"
        PUBLIC_READ = "public-read"
        PRIVATE = "private"
      end

      class LifeCycleRule
        attr_reader :id, :enabled, :prefix, :expiry

        def initialize(opts)
          @id = opts[:id]
          @enabled = opts[:enabled]
          @prefix = opts[:prefix]
          @expiry = opts[:expiry]
        end
      end

      attr_reader :name, :location, :creation_time

      # 构造一个Bucket
      def initialize(name, location, creation_time)
        @name, @location, @creation_time = name, location, creation_time
      end

    end # Bucket
  end # OSS
end # Aliyun
