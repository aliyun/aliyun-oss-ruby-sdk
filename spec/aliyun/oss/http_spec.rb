# -*- encoding: utf-8 -*-

require 'spec_helper'

module Aliyun
  module OSS

    describe HTTP do

      context HTTP::StreamWriter do
        it "should read out chunks that are written" do
          s = HTTP::StreamWriter.new do |sr|
            10.times{ |i| sr << "hello, #{i}" }
          end

          10.times do |i|
            bytes, outbuf = "hello, 0".size, ""
            s.read(bytes, outbuf)
            expect(outbuf).to eq("hello, #{i}")
          end
        end
      end # StreamWriter

    end # HTTP
  end # OSS
end # Aliyun
