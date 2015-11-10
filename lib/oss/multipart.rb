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

        include Struct::Base

        attrs :id, :object_key, :creation_time, :checkpoint_file

        def upload
          @parts ||= []
        end

        def download
        end

        def rebuild!

        end

        def checkpoint!
        end
      end # Transaction

      ##
      # A part in a multipart uploading transaction
      #
      class Part

        include Struct::Base

        attrs :number, :etag, :size, :last_modified

        def number=(n)
          @number = n
        end

        def etag=(e)
          @etag = e
        end
      end # Part

      ##
      # A checkpoint for a multipart uploading transaction. It can be
      # used resume and complete a transaction after interrupted.
      #
      class CheckPoint

        include Struct::Base

        attrs :txn_id, :parts

      end # CheckPoint

    end # Multipart

  end # OSS
end # Aliyun
