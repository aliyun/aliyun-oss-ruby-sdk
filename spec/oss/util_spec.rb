# -*- encoding: utf-8 -*-

require 'spec_helper'

module Aliyun
  module OSS

    describe Util do
      it "should get GMT date" do
        date = Util.get_date
        pattern = ""
        pattern += "([[:alpha:]]{3}), "
        pattern += "([[:digit:]]{2}) "
        pattern += "([[:alpha:]]{3}) "
        pattern += "([[:digit:]]{4}) "
        pattern += "([[:digit:]]{2}):([[:digit:]]{2}):([[:digit:]]{2}) "
        pattern += "GMT"
        m = date.match(Regexp.new(pattern))

        expect(m).not_to eq(nil)

        expect(%w(Sun Mon Tue Wed Thu Fri Sat)).to include(m[1])
        expect((1..31)).to cover(m[2].to_i)
        expect(%w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)).to include(m[3])
        expect((0..23)).to cover(m[5].to_i)
        expect((0..59)).to cover(m[6].to_i)
        expect((0..59)).to cover(m[7].to_i)
      end

      it "should get correct content md5" do
        content = ""

        md5 = Util.get_content_md5(content)
        expect(md5).to eq("1B2M2Y8AsgTpgAmY7PhCfg==\n")

        content = "hello world"
        md5 = Util.get_content_md5(content)
        expect(md5).to eq("XrY7u+Ae7tCTyyK7j1rNww==\n")
      end

      it "should get correct signature" do
        key = 'helloworld'
        date = 'Fri, 30 Oct 2015 07:21:00 GMT'

        signature = Util.get_signature(key, 'GET', {'Date' => date}, {})
        expect(signature).to eq("u8QKAAj/axKX4JhHXa5DYfYSPxE=\n")

        signature = Util.get_signature(
          key, 'PUT', {'Date' => date}, {:path => '/bucket'})
        expect(signature).to eq("lMKrMCJIuGygd8UsdMA+S0QOAsQ=\n")

        signature = Util.get_signature(
          key, 'PUT',
          {'Date' => date, 'x-oss-copy-source' => '/bucket/object-old'},
          {:path => '/bucket/object-new'})
        expect(signature).to eq("McYUmBaErN//yvE9voWRhCgvsIc=\n")

        signature = Util.get_signature(
          key, 'PUT',
          {'Date' => date},
          {:path => '/bucket/object-new',
           :params => {'append' => nil, 'position' => 0}})
        expect(signature).to eq("7Oh2wobzeg6dw/cWYbF/2m6s6qc=\n")
      end

    end # Util

  end # OSS
end # Aliyun
