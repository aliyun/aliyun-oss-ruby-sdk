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
        attr_accessor :id, :object_key, :creation_time

        def initialize(opts = {})
          @id = opts[:id]
          @object_key = opts[:object_key]
          @creation_time = opts[:creation_time]
        end
      end

      ##
      # A part in a multipart uploading transaction
      #
      class Part
        attr_accessor :number, :etag
        attr_reader :size, :last_modified

        def initialize(opts = {})
          @number = opts[:number]
          @etag = opts[:etag]
          @size = opts[:size]
          @last_modified = opts[:last_modified]
        end
      end

      ##
      # A checkpoint for a multipart uploading transaction. It can be
      # used resume and complete a transaction after interrupted.
      #
      class CheckPoint
        attr_reader :txn_id, :parts

        def self.create(txn_id, parts)
          self.new
        end
      end

    end # Multipart

  end # OSS
end # Aliyun
