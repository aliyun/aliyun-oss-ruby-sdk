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

        private
        # Persist transaction states to file
        def write_checkpoint(states, file)
          states[:md5] = Util.get_content_md5(states.to_json)
          File.open(file, 'w'){ |f| f.write(states.to_json) }
        end

        # Load transaction states from file
        def load_checkpoint(file)
          states = JSON.load(File.read(file))
          states.symbolize_keys!
          md5 = states.delete(:md5)
          raise TokenBrokenError.new("Missing :md5 in checkpoint.") unless md5
          raise TokenBrokenError.new("Unmatched checkpoint MD5.") \
                                    unless md5 == Util.get_content_md5(states.to_json)
          states
        end
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
