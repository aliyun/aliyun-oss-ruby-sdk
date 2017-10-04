# -*- encoding: utf-8 -*-

module Aliyun
  module OSS

    ##
    # OSS service's client class, which is for getting bucket list, creating or deleting bucket. For {OSS:Object} related operations, 
    # please use {OSS::Bucket}.
    # @example creates a Client object
    #   endpoint = 'oss-cn-hangzhou.aliyuncs.com'
    #   client = Client.new(
    #     :endpoint => endpoint,
    #     :access_key_id => 'access_key_id',
    #     :access_key_secret => 'access_key_secret')
    #   buckets = client.list_buckets
    #   client.create_bucket('my-bucket')
    #   client.delete_bucket('my-bucket')
    #   bucket = client.get_bucket('my-bucket')
    class Client

      # creates OSS client for buckets operations.
      # @param opts [Hash] options for creating the Client object
      # @option opts [String] :endpoint [required] OSS endpoint. It could be standard endpoint such as
      #  oss-cn-hangzhou.aliyuncs.com or user domain binded with the bucket
      # @option opts [String] :access_key_id [optional] user's ACCESS KEY ID，
      #  if not specified, then the request is anonymous.
      # @option opts [String] :access_key_secret [optional] user's ACCESS
      #  KEY SECRET，if not specified, then the request is anonymous.
      # @option opts [Boolean] :cname [optional] flag indicates if the endpoint is CNamed.
      # @option opts [Boolean] :upload_crc_enable [optional] specifies if the upload enabled with CRC. Default is true.
      # @option opts [Boolean] :download_crc_enable [optional] specifies if the download enabled with CRC. Default is false.
      # @option opts [String] :sts_token [optional] specifies STS's SecurityToken. If it's specified, then use STS for authorization.
      # @option opts [Fixnum] :open_timeout [optional] the connection timeout in seconds. By default it's 10s.
      # @option opts [Fixnum] :read_timeout [optional] the response's timeout in seconds. By default it's 120s.
      # @example standard endpoint
      #   oss-cn-hangzhou.aliyuncs.com
      #   oss-cn-beijing.aliyuncs.com
      # @example cname binded endpoint
      #   my-domain.com
      #   foo.bar.com
      def initialize(opts)
        fail ClientError, "Endpoint must be provided" unless opts[:endpoint]

        @config = Config.new(opts)
        @protocol = Protocol.new(@config)
      end

      # Lists all buckets of the account
      # @param opts [Hash] options for the list
      # @option opts [String] :prefix if it's specified, only buckets prefixed with it will be returned
      # @option opts [String] :marker if it's specified, only buckets whose key is larger than :marker will be returned.
      # @return [Enumerator<Bucket>] Bucket's iterator
      def list_buckets(opts = {})
        if @config.cname
          fail ClientError, "Cannot list buckets for a CNAME endpoint."
        end

        Iterator::Buckets.new(@protocol, opts).to_enum
      end

      # Creates a bucket
      # @param name [String] Bucket name
      # @param opts [Hash] options for creating the bucket（optional）
      # @option opts [:location] [String] the region for the new bucket. By default is oss-cn-hangzhou
      def create_bucket(name, opts = {})
        @protocol.create_bucket(name, opts)
      end

      # Deletes a bucket
      # @param name [String] Bucket name
      # @note If the bucket is not empty (has objects), then the deletion will fail.
      def delete_bucket(name)
        @protocol.delete_bucket(name)
      end

      # Checks if the bucket exists
      # @param name [String] Bucket name
      # @return [Boolean] If Bucket exists returns true; otherwise returns false.
      def bucket_exists?(name)
        exist = false

        begin
          @protocol.get_bucket_acl(name)
          exist = true
        rescue ServerError => e
          raise unless e.http_code == 404
        end

        exist
      end

      alias :bucket_exist? :bucket_exists?

      # Gets the bucket object for objects level operations
      # @param name [String] Bucket name
      # @return [Bucket] Bucket object
      def get_bucket(name)
        Bucket.new({:name => name}, @protocol)
      end

    end # Client
  end # OSS
end # Aliyun
