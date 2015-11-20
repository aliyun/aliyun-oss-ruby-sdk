# -*- encoding: utf-8 -*-

module Aliyun
  module OSS
    module Multipart
      ##
      # A multipart upload transaction
      #
      class Upload < Transaction
        PART_SIZE = 4 * 1024 * 1024
        READ_SIZE = 16 * 1024

        def initialize(protocol, opts)
          args = opts.dup
          @protocol = protocol
          @file = args.delete(:file)
          @checkpoint_file = args.delete(:cpt_file)
          @file_meta = {}
          @parts = []
          super(args)
        end

        # Run the upload transaction, which includes 3 stages:
        # * 1a. initiate(new upload) and divide parts
        # * 1b. rebuild states(resumed upload)
        # * 2.  upload each unfinished part
        # * 3.  commit the multipart upload transaction
        def run
          logger.info("Begin upload, file: #{@file}, checkpoint file: " \
                      "#{@checkpoint_file}")

          # Rebuild transaction states from checkpoint file
          # Or initiate new transaction states
          rebuild

          # Divide the file to upload into parts to upload separately
          divide_parts if @parts.empty?

          # Upload each part
          @parts.reject { |p| p[:done] }.each { |p| upload_part(p) }

          # Commit the multipart upload transaction
          commit

          logger.info("Done upload, file: #{@file}")
        end

        # Checkpoint structures:
        # @example
        #   states = {
        #     :id => 'upload_id',
        #     :file => 'file',
        #     :file_meta => {
        #       :mtime => Time.now,
        #       :md5 => 1024
        #     },
        #     :parts => [
        #       {:number => 1, :range => [0, 100], :done => false},
        #       {:number => 2, :range => [100, 200], :done => true}
        #     ],
        #     :md5 => 'states_md5'
        #   }
        def checkpoint
          logger.debug("Begin make checkpoint, disable_cpt: #{options[:disable_cpt]}")

          ensure_file_not_changed

          states = {
            :id => id,
            :file => @file,
            :file_meta => @file_meta,
            :parts => @parts
          }

          write_checkpoint(states, @checkpoint_file) unless options[:disable_cpt]

          logger.debug("Done make checkpoint, states: #{states}")
        end

        private
        # Commit the transaction when all parts are succefully uploaded
        # @todo handle undefined behaviors: commit succeeds in server
        #  but return error in client
        def commit
          logger.info("Begin commit transaction, id: #{id}")

          parts = @parts.map{ |p| Part.new(:number  => p[:number], :etag => p[:etag])}
          @protocol.complete_multipart_upload(bucket, object, id, parts)

          File.delete(@checkpoint_file) unless options[:disable_cpt]

          logger.info("Done commit transaction, id: #{id}")
        end

        # Rebuild the states of the transaction from checkpoint file
        def rebuild
          logger.info("Begin rebuild transaction, checkpoint: #{@checkpoint_file}")

          if File.exists?(@checkpoint_file) and not options[:disable_cpt]
            states = load_checkpoint(@checkpoint_file)

            if states[:file_md5] != @file_meta[:md5]
              fail FileInconsistentError.new("The file to upload is changed.")
            end

            @id = states[:id]
            @file_meta = states[:file_meta]
            @parts = states[:parts]
          else
            initiate
          end

          logger.info("Done rebuild transaction, states: #{states}")
        end

        def initiate
          logger.info("Begin initiate transaction")

          @id = @protocol.initiate_multipart_upload(bucket, object, options)
          @file_meta = {
            :mtime => File.mtime(@file),
            :md5 => get_file_md5(@file)
          }
          checkpoint

          logger.info("Done initiate transaction, id: #{id}")
        end

        # Upload a part
        def upload_part(p)
          logger.debug("Begin upload part: #{p}")

          result = nil
          File.open(@file) do |f|
            range = p[:range]
            pos = range.first
            f.seek(pos)

            result = @protocol.upload_part(bucket, object, id, p[:number]) do |sw|
              while pos < range.at(1)
                bytes = [READ_SIZE, range.at(1) - pos].min
                sw << f.read(bytes)
                pos += bytes
              end
            end
          end
          p[:done] = true
          p[:etag] = result.etag

          checkpoint

          logger.debug("Done upload part: #{p}")
        end

        # Devide the file into parts to upload
        def divide_parts
          logger.info("Begin divide parts, file: #{@file}")

          max_parts = 10000
          file_size = File.size(@file)
          part_size = [@options[:part_size] || PART_SIZE, file_size / max_parts].max
          num_parts = (file_size - 1) / part_size + 1
          @parts = (1..num_parts).map do |i|
            {
              :number => i,
              :range => [(i-1) * part_size, [i * part_size, file_size].min],
              :done => false
            }
          end

          checkpoint

          logger.info("Done divide parts, parts: #{@parts}")
        end

        # Ensure file not changed during uploading
        def ensure_file_not_changed
          return if File.mtime(@file) == @file_meta[:mtime]

          if @file_meta[:md5] != get_file_md5(@file)
            fail FileInconsistentError, "The file to upload is changed."
          end
        end
      end # Upload

    end # Multipart
  end # OSS
end # Aliyun
