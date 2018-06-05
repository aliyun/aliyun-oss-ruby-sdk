# -*- encoding: utf-8 -*-

require 'logger'

module Aliyun
  module Common
    ##
    # Logging support
    # @example
    #   include Logging
    #   logger.info(xxx)
    module Logging

      DEFAULT_LOG_FILE = "./aliyun_sdk.log"
      MAX_NUM_LOG = 100
      ROTATE_SIZE = 10 * 1024 * 1024

      # level = Logger::DEBUG | Logger::INFO | Logger::ERROR | Logger::FATAL
      def self.set_log_level(level)
        Logging.logger.level = level
      end

      # set logger output file
      def self.set_log_file(file)
        @log_file = file
      end

      # get logger
      def logger
        Logging.logger
      end

      private

      def self.logger
        unless @logger
          @logger = Logger.new(
            @log_file ||= DEFAULT_LOG_FILE, MAX_NUM_LOG, ROTATE_SIZE)
          @logger.level = Logger::INFO
        end
        @logger
      end

    end # logging
  end # Common
end # Aliyun
