# -*- encoding: utf-8 -*-

module Aliyun
  module OSS
    ##
    # Iterator structs that wrap the multiple communications with the
    # server to provide an iterable result.
    #
    module Iterator

      class Base

        def initialize(opts = {})
          @results, @more = [], opts
        end

        def next
          loop do
            # Communicate with the server to get more results
            fetch_more if @results.empty?

            # Return the first result
            r = @results.shift
            break unless r

            yield r
          end
        end

        def to_enum
          self.enum_for(:next)
        end

        private
        def fetch_more
          return if @more[:truncated] == false
          fetch(@more)
        end
      end

      class Buckets < Base
        def fetch(more)
          @results, @more = Protocol.list_buckets(more)
          @more[:marker] = @more.delete(:next_marker)
        end
      end # Buckets

      class Objects < Base
        def initialize(bucket_name, opts = {})
          super(opts)
          @bucket = bucket_name
        end

        def fetch(more)
          @results, @more = Protocol.list_objects(@bucket, more)
          @more[:marker] = @more.delete(:next_marker)
        end
      end # Objects

      class CommonPrefixes < Base
        def initialize(bucket_name, opts = {})
          super(opts)
          @bucket = bucket_name
        end

        def fetch(more)
          _, @more = Protocol.list_objects(@bucket, more)
          @results = @more.delete(:common_prefixes) || []
          @more[:marker] = @more.delete(:next_marker)
        end
      end # CommonPrefixes

      class Multiparts < Base
        def initialize(bucket_name, opts = {})
          super(opts)
          @bucket = bucket_name
        end

        def fetch(more)
          @results, @more = Protocol.list_multipart_transactions(@bucket, more)
          @more[:id_marker] = @more.delete(:next_id_marker)
          @more[:key_marker] = @more.delete(:next_key_marker)
        end
      end # Multiparts

    end # Iterator
  end # OSS
end # Aliyun
