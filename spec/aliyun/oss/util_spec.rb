# -*- encoding: utf-8 -*-

require 'spec_helper'

module Aliyun
  module OSS

    describe Util do
      # 测试对body content的md5编码是否正确
      it "should get correct content md5" do
        content = ""

        md5 = Util.get_content_md5(content)
        expect(md5).to eq("1B2M2Y8AsgTpgAmY7PhCfg==")

        content = "hello world"
        md5 = Util.get_content_md5(content)
        expect(md5).to eq("XrY7u+Ae7tCTyyK7j1rNww==")
      end

      # 测试签名是否正确
      it "should get correct signature" do
        key = 'helloworld'
        date = 'Fri, 30 Oct 2015 07:21:00 GMT'

        signature = Util.get_signature(key, 'GET', {'Date' => date}, {})
        expect(signature).to eq("u8QKAAj/axKX4JhHXa5DYfYSPxE=")

        signature = Util.get_signature(
          key, 'PUT', {'Date' => date}, {:path => '/bucket'})
        expect(signature).to eq("lMKrMCJIuGygd8UsdMA+S0QOAsQ=")

        signature = Util.get_signature(
          key, 'PUT',
          {'Date' => date, 'x-oss-copy-source' => '/bucket/object-old'},
          {:path => '/bucket/object-new'})
        expect(signature).to eq("McYUmBaErN//yvE9voWRhCgvsIc=")

        signature = Util.get_signature(
          key, 'PUT',
          {'Date' => date},
          {:path => '/bucket/object-new',
           :sub_res => {'append' => nil, 'position' => 0}})
        expect(signature).to eq("7Oh2wobzeg6dw/cWYbF/2m6s6qc=")
      end

    end # Util

  end # OSS
end # Aliyun
