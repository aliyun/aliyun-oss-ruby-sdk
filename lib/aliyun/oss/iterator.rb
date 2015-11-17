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
        def initialize(protocol, opts = {})
          @protocol = protocol
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
          @results, cont = @protocol.list_buckets(more)
          @more[:marker] = cont[:next_marker]
          @more[:truncated] = cont[:truncated] || false
        end
      end # Buckets

      ##
      # Objects iterator
      #
      class Objects < Base
        def initialize(protocol, bucket_name, opts = {})
          super(protocol, opts)
          @bucket = bucket_name
        end

        def fetch(more)
          @results, cont = @protocol.list_objects(@bucket, more)
          @results += cont[:common_prefixes] if cont[:common_prefixes]
          @more[:marker] = cont[:next_marker]
          @more[:truncated] = cont[:truncated] || false
        end
      end # Objects

    end # Iterator
  end # OSS
end # Aliyun
