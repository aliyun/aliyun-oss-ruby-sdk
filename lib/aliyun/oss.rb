# -*- encoding: utf-8 -*-

require_relative 'common'
require_relative 'oss/util'
require_relative 'oss/exception'
require_relative 'oss/struct'
require_relative 'oss/config'
require_relative 'oss/http'
require_relative 'oss/protocol'
require_relative 'oss/multipart'
require_relative 'oss/upload'
require_relative 'oss/download'
require_relative 'oss/iterator'
require_relative 'oss/object'
require_relative 'oss/bucket'
require_relative 'oss/client'
require_relative 'crcx' unless RUBY_PLATFORM =~ /java/