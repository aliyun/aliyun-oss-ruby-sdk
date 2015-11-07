# -*- encoding: utf-8 -*-

module Aliyun
  module OSS
    ##
    # Common structs used
    #

    module Struct
      module ACL
        PUBLIC_READ_WRITE = "public-read-write"
        PUBLIC_READ = "public-read"
        PRIVATE = "private"
      end # ACL

      module MetaDirective
        COPY = "COPY"
        REPLACE = "REPLACE"
      end # MetaDirective

      module KeyEncoding
        URL = "url"

        @@all = [URL]

        def self.include?(enc)
          all.include?(enc)
        end

        def self.all
          @@all
        end
      end # KeyEncoding

      module Base
        def self.included(base)
          base.extend(AttrHelper)
        end

        module AttrHelper
          def attrs(*s)
            define_method(:attrs) {s}
            attr_reader(*s)
          end
        end

        def initialize(opts = {})
          attrs.each do |attr|
            instance_variable_set("@#{attr}", opts[attr])
          end
        end

        def to_s
          attrs.map do |attr|
            v = instance_variable_get("@#{attr}")
            "#{attr.to_s}: #{v}"
          end.join(",")
        end
      end # Base

      class LifeCycleRule

        include Base

        attrs :id, :enabled, :prefix, :expiry

      end # LifeCycleRule

      class CORSRule

        include Base

        attrs :allowed_origins, :allowed_methods, :allowed_headers,
              :expose_headers, :max_age_seconds

      end # CORSRule

    end # Struct

  end # OSS
end # Aliyun
