# -*- encoding: utf-8 -*-

module Aliyun
  module OSS
    module Multipart
      ##
      # A multipart download transaction
      #
      class Download < Transaction
        PART_SIZE = 10 * 1024 * 1024
        READ_SIZE = 16 * 1024

        def initialize(protocol, opts)
          super(opts)
          @protocol = protocol
          @file, @checkpoint_file = opts[:file], opts[:cpt_file]
          @object_meta = {}
          @parts = []
        end

        # Run the download transaction, which includes 3 stages:
        # * 1a. initiate(new downlaod) and divide parts
        # * 1b. rebuild states(resumed download)
        # * 2.  download each unfinished part
        # * 3.  combine the downloaded parts into the final file
        def run
          logger.info("Begin download, file: #{@file}, checkpoint file: " \
                      " #{@checkpoint_file}")

          # Rebuild transaction states from checkpoint file
          # Or initiate new transaction states
          rebuild!

          # Divide the target object into parts to download by ranges
          divide_parts! if @parts.empty?

          # Download each part(object range)
          @parts.reject {|p| p[:done]}.each do |p|
            download_part!(p)
          end

          # Combine the parts into the final file
          commit!

          logger.info("Done download, file: #{@file}")
        end

        # Checkpoint structures:
        # @example
        #   states = {
        #     :id => 'download_id',
        #     :file => 'file',
        #     :object_meta => {
        #       :etag => 'xxx',
        #       :size => 1024
        #     },
        #     :parts => [
        #       {:number => 1, :range => [0, 100], :md5 => 'xxx', :done => false},
        #       {:number => 2, :range => [100, 200], :md5 => 'yyy', :done => true}
        #     ],
        #     :md5 => 'states_md5'
        #   }
        def checkpoint!
          logger.debug("Begin make checkpoint, disable_cpt: #{options[:disable_cpt]}")

          ensure_object_not_changed

          states = {
            :id => id,
            :file => @file,
            :object_meta => @object_meta,
            :parts => @parts
          }

          write_checkpoint(states, @checkpoint_file) unless options[:disable_cpt]

          logger.debug("Done make checkpoint, states: #{states}")
        end

        private
        # Combine the downloaded parts into the final file
        # @todo avoid copy all part files
        def commit!
          logger.info("Begin commit transaction, id: #{id}")

          # concat all part files into the target file
          File.open(@file, 'w') do |w|
            @parts.sort{ |x, y| x[:number] <=> y[:number] }.each do |p|
              File.open(get_part_file(p[:number])) do |r|
                  w.write(r.read(READ_SIZE)) until r.eof?
              end
            end
          end

          File.delete(@checkpoint_file) unless options[:disable_cpt]
          @parts.each{ |p| File.delete(get_part_file(p[:number])) }

          logger.info("Done commit transaction, id: #{id}")
        end

        # Rebuild the states of the transaction from checkpoint file
        def rebuild!
          logger.info("Begin rebuild transaction, checkpoint: #{@checkpoint_file}")

          if File.exists?(@checkpoint_file) and not options[:disable_cpt]
            states = load_checkpoint(@checkpoint_file)

            states[:parts].select{ |p| p[:done] }.each do |p|
              part_file = get_part_file(p[:number])
              raise PartMissingError.new("The part file is missing.") \
                                        unless File.exist?(part_file)
              raise FileInconsistentError.new("The part file is changed.") \
                                        if p[:md5] != Digest::MD5.file(part_file).to_s
            end
            @id = states[:id]
            @object_meta = states[:object_meta]
            @parts = states[:parts]
          else
            initiate!
          end

          logger.info("Done rebuild transaction, states: #{states}")
        end

        def initiate!
          logger.info("Begin initiate transaction")

          @id = generate_download_id
          obj = @protocol.get_object_meta(bucket, object)
          @object_meta = {
            :etag => obj.etag,
            :size => obj.size
          }
          checkpoint!

          logger.info("Done initiate transaction, id: #{id}")
        end

        # Download a part
        def download_part!(p)
          logger.debug("Begin download part: #{p}")

          part_file = get_part_file(p[:number])
          File.open(part_file, 'w') do |w|
            @protocol.get_object(bucket, object, :range => p[:range]) do |chunk|
              w.write(chunk)
            end
          end

          p[:done] = true
          p[:md5] = Digest::MD5::file(part_file).to_s

          checkpoint!

          logger.debug("Done download part: #{p}")
        end

        # Devide the object to download into parts to download
        def divide_parts!
          logger.info("Begin divide parts, object: #{@object}")

          max_parts = 100
          object_size = @object_meta[:size]
          part_size = [@options[:part_size] || PART_SIZE, object_size / max_parts].max
          num_parts = (object_size - 1) / part_size + 1
          @parts = (1..num_parts).map do |i|
            {
              :number => i,
              :range => [(i-1) * part_size, [i * part_size, object_size].min],
              :done => false
            }
          end

          checkpoint!

          logger.info("Done divide parts, parts: #{@parts}")
        end

        # Ensure file not changed during uploading
        def ensure_object_not_changed
          obj = @protocol.get_object_meta(bucket, object)
          raise ObjectInconsistentError.new("The object to download is changed.") \
                                           unless obj.etag == @object_meta[:etag]

        end

        # Generate a download id
        def generate_download_id
          "download_#{bucket}_#{object}_#{Time.now.to_i}"
        end

        # Get name for part file
        def get_part_file(number)
          "#{@file}.part.#{number}"
        end
      end # Download

    end # Multipart
  end # OSS
end # Aliyun
