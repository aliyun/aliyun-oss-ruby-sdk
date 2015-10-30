# -*- encoding: utf-8 -*-

module Aliyun
  module OSS

    ##
    # Object表示OSS存储的一个对象
    class Object
      attr_reader :key, :type, :size, :etag, :last_modified
      # 构造一个Object
      def initialize(attrs)
        @key = attrs[:key]
        @type = attrs[:type]
        @size = attrs[:size]
        @etag = attrs[:etag]
        @last_modified = attrs[:last_modified]
      end

    end # Object

  end # OSS
end # Aliyun
