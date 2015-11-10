# -*- encoding: utf-8 -*-

module Aliyun
  module OSS

    ##
    # Multipart uploading structures
    #
    module Multipart

      ##
      # A multipart uploading transaction
      #
      class Transaction

        include Logging
        include Struct::Base

        attrs :id, :object, :bucket, :creation_time, :options

      end # Transaction

      ##
      # A part in a multipart uploading transaction
      #
      class Part

        include Struct::Base

        attrs :number, :etag, :size, :last_modified

      end # Part

    end # Multipart
  end # OSS
end # Aliyun
