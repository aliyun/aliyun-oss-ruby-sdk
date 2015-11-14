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
          id = 'xxx'
          key = 'yyy'
          Client.new(endpoint, id, key)

          expect(Config.get(:endpoint)).to eq(endpoint)
          expect(Config.get(:access_id)).to eq(id)
          expect(Config.get(:access_key)).to eq(key)
        end

        it "should connect to bucket" do
          endpoint = 'oss-cn-hangzhou.aliyuncs.com'
          id = 'xxx'
          key = 'yyy'
          bucket_name = 'rubysdk-bucket'
          bucket = Client.connect_to_bucket(bucket_name, endpoint, id, key)

          expect(bucket.name).to eq(bucket_name)
          expect(Config.get(:endpoint)).to eq(endpoint)
          expect(Config.get(:access_id)).to eq(id)
          expect(Config.get(:access_key)).to eq(key)
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

      context "list buckets" do
        it "should paging buckets" do
          endpoint = 'oss.aliyuncs.com'
          id, key = 'xxx', 'yyy'

          client = Client.new(endpoint, id, key)

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

          stub_request(:get, /#{endpoint}.*/)
            .to_return(:body => mock_buckets(return_buckets_1, more_1)).then
            .to_return(:body => mock_buckets(return_buckets_2, more_2))

          buckets = client.list_buckets

          expect(buckets.map {|b| b.to_s}.join(";"))
            .to eq((return_buckets_1 + return_buckets_2).map {|b| b.to_s}.join(";"))
          expect(WebMock).to have_requested(:get, /#{endpoint}.*/).times(2)
        end
      end

    end # Client

  end # OSS
end # Aliyun
