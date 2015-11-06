# -*- encoding: utf-8 -*-

module Aliyun
  module OSS

    ##
    # Object表示OSS存储的一个对象
    #
    class Object

      include Struct::Base

      attrs :key, :type, :size, :etag, :last_modified

    end # Object
  end # OSS
end # Aliyun
