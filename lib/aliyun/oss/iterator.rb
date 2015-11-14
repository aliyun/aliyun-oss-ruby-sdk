# -*- encoding: utf-8 -*-

module Aliyun
  module OSS
    ##
    # Iterator structs that wrap the multiple communications with the
    # server to provide an iterable result.
    #
    module Iterator

      ##
      # Iterator base that stores fetched results and fetch more if needed.
      #
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
      end # Base

      ##
      # Buckets iterator
      #
      class Buckets < Base
        def fetch(more)
          @results, cont = Protocol.list_buckets(more)
          @more[:marker] = cont[:next_marker]
          @more[:truncated] = cont[:truncated] || false
        end
      end # Buckets

      ##
      # Objects iterator
      #
      class Objects < Base
        def initialize(bucket_name, opts = {})
          super(opts)
          @bucket = bucket_name
        end

        def fetch(more)
          @results, cont = Protocol.list_objects(@bucket, more)
          @results += cont[:common_prefixes] if cont[:common_prefixes]
          @more[:marker] = cont[:next_marker]
          @more[:truncated] = cont[:truncated] || false
        end
      end # Objects

      ##
      # Multiparts iterator
      #
      class Multiparts < Base
        def initialize(bucket_name, opts = {})
          super(opts)
          @bucket = bucket_name
        end

        def fetch(more)
          @results, cont = Protocol.list_multipart_transactions(@bucket, more)
          @more[:id_marker] = cont[:next_id_marker]
          @more[:key_marker] = cont[:next_key_marker]
          @more[:truncated] = cont[:truncated] || false
        end
      end # Multiparts

    end # Iterator
  end # OSS
end # Aliyun
