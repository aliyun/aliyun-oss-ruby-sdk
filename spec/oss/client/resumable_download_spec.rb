# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'yaml'
require 'nokogiri'

module Aliyun
  module OSS

    describe "Resumable download" do

      before :all do
        @endpoint = 'oss-cn-hangzhou.aliyuncs.com'
        @bucket_name = 'rubysdk-bucket'
        @object_key = 'resumable_file'
        @bucket = Client.new(@endpoint, 'xxx', 'yyy').get_bucket(@bucket_name)

        @file = './download_file'
      end

      before :each do
        File.delete("#{@file}.token") if File.exist?("#{@file}.token")
      end

      def object_url
        "#{@bucket_name}.#{@endpoint}/#{@object_key}"
      end

      def mock_object(i)
        i.to_s.rjust(9, '0') + "\n"
      end

      def mock_range(i)
        "bytes=#{(i-1)*10}-#{i*10 - 1}"
      end

      def mock_error(code, message)
        Nokogiri::XML::Builder.new do |xml|
          xml.Error {
            xml.Code code
            xml.Message message
            xml.RequestId '0000'
          }
        end.to_xml
      end

      it "should download file when all goes well" do
        return_headers = {
          'x-oss-object-type' => 'Normal',
          'ETag' => 'xxxyyyzzz',
          'Content-Length' => 100,
          'Last-Modified' => Time.now.rfc822
        }

        # get object meta
        stub_request(:head, object_url).to_return(:headers => return_headers)

        # get object by range
        stub_request(:get, object_url)
          .to_return((1..10).map{ |i| {:body => mock_object(i)} })

        @bucket.resumable_download(@object_key, @file, :part_size => 10)

        ranges = []
        expect(WebMock).to have_requested(:get, object_url).with{ |req|
          ranges << req.headers['Range']
        }.times(10)

        expect(ranges).to match_array((1..10).map{ |i| mock_range(i) })
        expect(File.exist?("#{@file}.token")).to be false
        expect(Dir.glob("#{@file}.part.*").empty?).to be true

        expect(File.read(@file)).to eq((1..10).map{ |i| mock_object(i) }.join)
      end

      it "should resume when download part fails", :focus => true do
        return_headers = {
          'x-oss-object-type' => 'Normal',
          'ETag' => 'xxxyyyzzz',
          'Content-Length' => 100,
          'Last-Modified' => Time.now.rfc822
        }

        # get object meta
        stub_request(:head, object_url).to_return(:headers => return_headers)

        code = 'Timeout'
        message = 'Request timeout.'
        # upload part
        stub_request(:get, object_url)
          .to_return((1..3).map{ |i| {:body => mock_object(i)} }).then
          .to_return(:status => 500, :body => mock_error(code, message)).times(2).then
          .to_return((4..9).map{ |i| {:body => mock_object(i)} }).then
          .to_return(:status => 500, :body => mock_error(code, message)).then
          .to_return((10..10).map{ |i| {:body => mock_object(i)} })

        4.times do
          begin
            @bucket.resumable_download(@object_key, @file, :part_size => 10)
          rescue
            # pass
          end
        end

        ranges = []
        expect(WebMock).to have_requested(:get, object_url).with{ |req|
          ranges << req.headers['Range']
        }.times(13)

        expect(ranges).to match_array((1..10).map{ |i| mock_range(i) })
        expect(File.read(@file)).to eq((1..10).map{ |i| mock_object(i) }.join)
      end

      it "should resume when checkpoint fails" do
        # Monkey patch to inject failures
        class ::Aliyun::OSS::Multipart::Download
          alias :old_checkpoint! :checkpoint!

          def checkpoint_fails
            @@fail_injections ||= [false, false, true, true, false, true, false]
            @@fail_injections.shift
          end

          def checkpoint!
            t = checkpoint_fails
            if t == true
              raise ClientError.new("fail injection")
            end

            old_checkpoint!
          end
        end

        return_headers = {
          'x-oss-object-type' => 'Normal',
          'ETag' => 'xxxyyyzzz',
          'Content-Length' => 100,
          'Last-Modified' => Time.now.rfc822
        }

        # get object meta
        stub_request(:head, object_url).to_return(:headers => return_headers)

        # get object by range
        returns = [1, 1, 1, 2, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        stub_request(:get, object_url)
          .to_return(returns.map{ |i| {:body => mock_object(i)} })

        4.times do
          begin
            @bucket.resumable_download(@object_key, @file, :part_size => 10)
          rescue
            # pass
          end
        end

        expect(WebMock).to have_requested(:get, object_url).times(13)
        expect(File.read(@file)).to eq((1..10).map{ |i| mock_object(i) }.join)
      end

    end # Resumable upload
  end # OSS
end # Aliyun
