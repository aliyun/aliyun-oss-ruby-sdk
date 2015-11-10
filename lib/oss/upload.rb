# -*- encoding: utf-8 -*-

module Aliyun
  module OSS

    ##
    # Multipart uploading structures
    #
    module Multipart

      ##
      # A multipart upload transaction
      #
      class Upload < Transaction
        def initialize(opts)
          super(opts)
          @file, @checkpoint_file = opts[:file], opts[:resume_token]
          @file_meta = {}
          @parts = []
        end

        def run
          logger.info("Begin upload, file: #{@file}, checkpoint file: #{@checkpoint_file}")

          rebuild!

          divide_parts! if @parts.empty?

          @parts.reject {|p| p[:done]}.each do |p|
            upload_part!(p)
          end

          commit!

          logger.info("Done upload, file: #{@file}")
        end

        # Checkpoint structures:
        # status = {
        #   :id => 'upload_id',
        #   :file => 'file',
        #   :file_meta => {
        #     :mtime => Time.now,
        #     :md5 => 1024
        #   },
        #   :parts => [
        #     {:number => 1, :range => [0, 100], :done => false},
        #     {:number => 2, :range => [100, 200], :done => true}
        #   ],
        #   :md5 => 'checkpoint_md5'
        # }
        def checkpoint!
          logger.info("Begin make checkpoint")

          ensure_file_not_changed

          status = {
            :id => id,
            :file => @file,
            :file_meta => @file_meta,
            :parts => @parts
          }

          status[:md5] = Util.get_content_md5(status.to_json)

          File.open(@checkpoint_file, 'w') do |f|
            f.write(status.to_json)
          end

          logger.info("Done make checkpoint, status: #{status}")
        end

        private
        # Commit the transaction when all parts are succefully uploaded
        # @todo handle undefined behaviors: commit succeeds in server
        #  but return error in client
        def commit!
          logger.info("Begin commit transaction, id: #{id}")

          parts = @parts.map{ |p| Part.new(:number  => p[:number], :etag => p[:etag])}
          Protocol.commit_multipart(bucket, object, id, parts)

          File.delete(@checkpoint_file)

          logger.info("Done commit transaction, id: #{id}")
        end

        # Rebuild the status of the transaction from token file
        def rebuild!
          logger.info("Begin rebuild transaction, checkpoint: #{@checkpoint_file}")

          if File.exists?(@checkpoint_file)
            status = load_checkpoint
            md5 = status.delete(:md5)
            raise TokenInconsistentError.new("The resume token is changed.") \
                                            if md5 != Util.get_content_md5(status.to_json)

            file_md5 = status[:file_md5]
            raise FileInconsistentError.new("The file to upload is changed.") \
                                           if file_md5 != @file_meta[:md5]
            @id = status[:id]
            @file_meta = status[:file_meta]
            @parts = status[:parts]
          else
            initiate!
          end

          logger.info("Done rebuild transaction, status: #{status}")
        end

        def initiate!
          logger.info("Begin initiate transaction")

          @id = Protocol.begin_multipart(bucket, object, options)
          @file_meta = {
            :mtime => File.mtime(@file),
            :md5 => Digest::MD5.file(@file).to_s
          }
          checkpoint!

          logger.info("Done initiate transaction, id: #{id}")
        end

        # Upload a part
        def upload_part!(p)
          logger.info("Begin upload part: #{p}")

          result = nil
          File.open(@file) do |f|
            range = p[:range]
            f.seek(range.first)

            result = Protocol.upload_part(bucket, object, id, p[:number]) do |sw|
              sw << f.read(range.at(1) - range.at(0)) << HTTP::ENDS
            end
          end
          p[:done] = true
          p[:etag] = result.etag

          checkpoint!

          logger.info("Done upload part: #{p}")
        end

        # Devide the file into parts to upload
        def divide_parts!
          logger.info("Begin divide parts, file: #{@file}")

          file_size = File.size(@file)
          part_size = @options[:part_size] || PART_SIZE
          num_parts = (file_size - 1) / part_size + 1
          @parts = (1..num_parts).map do |i|
            {
              :number => i,
              :range => [(i-1) * part_size, [i * part_size, file_size].min],
              :done => false
            }
          end

          checkpoint!

          logger.info("Done divide parts, parts: #{@parts}")
        end

        # Ensure file not changed during uploading
        def ensure_file_not_changed
          return if File.mtime(@file) == @file_meta[:mtime]

          file_md5 = Digest::MD5.file(@file)
          raise FileInconsistentError.new("The file to upload is changed.") \
                                         if file_md5 != @file_meta[:md5]

        end

        # Load transaction states from checkpoint file
        def load_checkpoint
          status = JSON.load(File.read(@checkpoint_file))
          status.symbolize_keys!
          status
        end
      end # Upload

    end # Multipart
  end # OSS
end # Aliyun
