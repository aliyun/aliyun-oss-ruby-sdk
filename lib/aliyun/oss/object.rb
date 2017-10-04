# -*- encoding: utf-8 -*-

module Aliyun
  module OSS

    ##
    # Object represents an object in OSS
    #
    class Object < Common::Struct::Base

      attrs :key, :type, :size, :etag, :metas, :last_modified, :headers

    end # Object
  end # OSS
end # Aliyun
