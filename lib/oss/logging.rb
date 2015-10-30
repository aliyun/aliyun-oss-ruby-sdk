# -*- encoding: utf-8 -*-

require 'logger'

module Aliyun
  module OSS
    ##
    # 日志模块，包含了log level和log file的配置
    # 使用时只需要:
    #     include Logging
    #     logger.info(xxx)
    module Logging

      # 默认的log输出到的文件
      DEFAULT_LOG_FILE = "./oss_sdk.log"

      @@log_file = nil
      @logger = nil

      # 设置日志等级，可能的值是Logger::DEBUG, Logger::INFO,
      # Logger::ERROR, Logger::FATAL
      def self.set_log_level(level)
        Logging.logger.level = level
      end

      # 设置日志输出的文件
      def self.set_log_file(file)
      end

      # 获取logger
      def logger
        Logging.logger
      end

      private

      def self.logger
        @logger ||= Logger.new(@@log_file || DEFAULT_LOG_FILE)
      end

    end # logging
  end # OSS
end # Aliyun
