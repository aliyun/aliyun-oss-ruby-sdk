# -*- encoding: utf-8 -*-

require 'spec_helper'

module Aliyun
  module OSS

    describe HTTP do

      context HTTP::StreamReader do
        it "should read out chunks that are written" do
          sr = HTTP::StreamReader.new

          10.times do
            sr << 'hello world'
            bytes, outbuf = 0, ''
            sr.read(bytes, outbuf)

            expect(outbuf).to eq('hello world')
          end
        end

        it "should call block to fetch data" do
          called = 0
          sr = HTTP::StreamReader.new(lambda {|r| called += 1; r << 'hello world'})

          10.times do
            bytes, outbuf = 0, ''
            sr.read(bytes, outbuf)

            expect(outbuf).to eq('hello world')
          end

          expect(called).to eq(10)
        end

        it "should close when write HTTP::ENDS" do
          sr = HTTP::StreamReader.new

          expect(sr.closed?).to be false

          sr << 'hello world' << HTTP::ENDS

          expect(sr.closed?).to be true
        end

        it "should raise error when write a closed stream reader" do
          sr = HTTP::StreamReader.new
          sr << 'hello world' << HTTP::ENDS

          expect {
            sr << 'hello world'
          }.to raise_error(ClientError)
        end

        it "should read all chunk before closed" do
          sr = HTTP::StreamReader.new

          5.times {sr << 'hello world'}
          sr.close!

          5.times do
            bytes, outbuf = 0, ""
            sr.read(bytes, outbuf)

            expect(outbuf).to eq('hello world')
          end
        end

      end # StreamReader
    end # HTTP

  end # OSS
end # Aliyun
