# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'yaml'
require 'nokogiri'

module Aliyun
  module OSS

    describe Client do

      context "construct" do
        it "should setup endpoint and a/k" do
          endpoint = 'oss-cn-hangzhou.aliyuncs.com'
          Client.new(:endpoint => endpoint,
                     :access_key_id => 'xxx',
                     :access_key_secret => 'yyy')

          expect(Config.get(:endpoint).to_s).to eq("http://#{endpoint}")
          expect(Config.get(:access_id)).to eq('xxx')
          expect(Config.get(:access_key)).to eq('yyy')
        end

        it "should not set Authorization with anonymous client" do
          endpoint = 'oss-cn-hangzhou.aliyuncs.com'
          bucket = 'rubysdk-bucket'
          object = 'rubysdk-object'
          client = Client.new(:endpoint => endpoint)

          stub_request(:get, "#{bucket}.#{endpoint}/#{object}")

          client.get_bucket(bucket).get_object(object)

          expect(WebMock)
            .to have_requested(:get, "#{bucket}.#{endpoint}/#{object}")
            .with{ |req| not req.headers.has_key?('Authorization') }
        end
      end # construct

      def mock_buckets(buckets, more = {})
        Nokogiri::XML::Builder.new do |xml|
          xml.ListAllMyBucketsResult {
            xml.Owner {
              xml.ID 'owner_id'
              xml.DisplayName 'owner_name'
            }
            xml.Buckets {
              buckets.each do |b|
                xml.Bucket {
                  xml.Location b.location
                  xml.Name b.name
                  xml.CreationDate b.creation_time.to_s
                }
              end
            }

            unless more.empty?
              xml.Prefix more[:prefix]
              xml.Marker more[:marker]
              xml.MaxKeys more[:limit].to_s
              xml.NextMarker more[:next_marker]
              xml.IsTruncated more[:truncated]
            end
          }
        end.to_xml
      end

      def mock_location(location)
        Nokogiri::XML::Builder.new do |xml|
          xml.CreateBucketConfiguration {
            xml.LocationConstraint location
          }
        end.to_xml
      end

      context "bucket operations" do
        before :all do
          @endpoint = 'oss.aliyuncs.com'
          @client = Client.new(
            :endpoint => @endpoint,
            :access_key_id => 'xxx',
            :access_key_secret => 'yyy')
          @bucket = 'rubysdk-bucket'
        end

        def bucket_url
          @bucket + "." + @endpoint
        end

        it "should create bucket" do
          location = 'oss-cn-hangzhou'

          stub_request(:put, bucket_url).with(:body => mock_location(location))

          @client.create_bucket(@bucket, :location => 'oss-cn-hangzhou')

          expect(WebMock).to have_requested(:put, bucket_url)
            .with(:body => mock_location(location), :query => {})
        end

        it "should delete bucket" do
          stub_request(:delete, bucket_url)

          Protocol.delete_bucket(@bucket)

          expect(WebMock).to have_requested(:delete, bucket_url)
            .with(:body => nil, :query => {})
        end

        it "should paging list buckets" do
          return_buckets_1 = (1..5).map do |i|
            name = "rubysdk-bucket-#{i.to_s.rjust(3, '0')}"
            Bucket.new(
              :name => name,
              :location => 'oss-cn-hangzhou',
              :creation_time => Time.now)
          end

          more_1 = {:next_marker => return_buckets_1.last.name, :truncated => true}

          return_buckets_2 = (6..10).map do |i|
            name = "rubysdk-bucket-#{i.to_s.rjust(3, '0')}"
            Bucket.new(
              :name => name,
              :location => 'oss-cn-hangzhou',
              :creation_time => Time.now)
          end

          more_2 = {:truncated => false}

          stub_request(:get, /#{@endpoint}.*/)
            .to_return(:body => mock_buckets(return_buckets_1, more_1)).then
            .to_return(:body => mock_buckets(return_buckets_2, more_2))

          buckets = @client.list_buckets

          expect(buckets.map {|b| b.to_s}.join(";"))
            .to eq((return_buckets_1 + return_buckets_2).map {|b| b.to_s}.join(";"))
          expect(WebMock).to have_requested(:get, /#{@endpoint}.*/).times(2)
        end

        it "should not list buckets when endpoint is cname" do
          cname_client = Client.new(
            :endpoint => @endpoint,
            :access_key_id => 'xxx',
            :access_key_secret => 'yyy',
            :cname => true)

          expect {
            cname_client.list_buckets
          }.to raise_error(ClientError)
        end

        it "should use HTTPS" do
          stub_request(:put, "https://#{bucket_url}")

          https_client = Client.new(
            :endpoint => "https://#{@endpoint}",
            :access_key_id => 'xxx',
            :access_key_secret => 'yyy',
            :cname => false)

          https_client.create_bucket(@bucket)

          expect(WebMock).to have_requested(:put, "https://#{bucket_url}")
        end
      end # bucket operations

    end # Client

  end # OSS
end # Aliyun
