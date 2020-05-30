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

      # 设置日志输出的文件
      def self.set_log_file(file)
        @log_file = file
      end

      # 获取logger
      def logger
        Logging.logger
      end

      private

      def self.logger
        unless @logger
          @log_file = nil
          # Environment parameter ALIYUN_OSS_SDK_LOG_PATH used to control whether output log to a file
          if ENV['ALIYUN_OSS_SDK_LOG_PATH']
            @log_file ||= DEFAULT_LOG_FILE
          end
          @logger = Logger.new(
              @log_file, MAX_NUM_LOG, ROTATE_SIZE)
          @logger.level = Logger::INFO
        end
        @logger
      end

    end # logging
  end # Common
end # Aliyun
