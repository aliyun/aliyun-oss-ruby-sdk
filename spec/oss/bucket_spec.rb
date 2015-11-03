# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'yaml'
require 'nokogiri'

module Aliyun
  module OSS

    describe "Bucket" do

      before :all do
        @endpoint = 'oss.aliyuncs.com'

        cred_file = "~/.oss.yml"
        cred = YAML.load(File.read(File.expand_path(cred_file)))
        Aliyun::OSS::Logging.set_log_level(Logger::DEBUG)

        @oss = Client.new(@endpoint, cred['id'], cred['key'])
      end

      def get_request_path(bucket)
        bucket + "." + @endpoint
      end

      def mock_location(location)
          builder = Nokogiri::XML::Builder.new do |xml|
            xml.CreateBucketConfiguration {
              xml.LocationConstraint location
            }
          end
          builder.to_xml
      end

      def mock_objects(objects, more = {})
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.ListBucketResult {
            {
              :prefix => 'Prefix',
              :delimiter => 'Delimiter',
              :limit => 'MaxKeys',
              :marker => 'Marker',
              :next_marker => 'NextMarker',
              :truncated => 'IsTruncated',
              :encoding => 'encoding-type'
            }.map do |k, v|
              xml.send(v, more[k]) if more[k]
            end

            objects.each do |o|
              xml.Contents {
                xml.Key o
                xml.LastModified Time.now.to_s
                xml.Type 'Normal'
                xml.Size 1024
                xml.StorageClass 'Standard'
                xml.Etag 'etag'
                xml.Owner {
                  xml.ID '10086'
                  xml.DisplayName 'CMCC'
                }
              }
            end

            (more[:common_prefixes] || []).each do |p|
              xml.CommonPrefixes {
                xml.Prefix p
              }
            end
          }
        end

        builder.to_xml
      end

      context "Create bucket" do

        it "should PUT to create bucket" do
          bucket_name = 'rubysdk-bucket'
          url = get_request_path(bucket_name)
          stub_request(:put, url)

          @oss.create_bucket(bucket_name)

          expect(WebMock).to have_requested(:put, url)
            .with(:body => nil, :query => {})
        end

        it "should set location when create bucket" do
          bucket_name = 'rubysdk-bucket'
          location = 'oss-cn-hangzhou'
          url = get_request_path(bucket_name)

          stub_request(:put, url).with(:body => mock_location(location))

          @oss.create_bucket(bucket_name, :location => 'oss-cn-hangzhou')

          expect(WebMock).to have_requested(:put, url)
            .with(:body => mock_location(location), :query => {})
        end
      end # create bucket

      context "List objects" do

        it "should list all objects" do
          bucket_name = 'rubysdk-bucket'
          url = get_request_path(bucket_name)

          stub_request(:get, url)

          @oss.list_object(bucket_name)

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => {})
        end

        it "should parse object response" do
          bucket_name = 'rubysdk-bucket'
          url = get_request_path(bucket_name)

          return_objects = ['hello', 'world', 'foo/bar']
          stub_request(:get, url).to_return(:body => mock_objects(return_objects))

          objects, more = @oss.list_object(bucket_name)

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => {})

          expect(objects.map {|o| o.key}).to match_array(return_objects)
          expect(more).to be_empty
        end

        it "should list objects with prefix & delimiter" do
          bucket_name = 'rubysdk-bucket'
          url = get_request_path(bucket_name)

          # Webmock cannot capture the url encoded query parameters,
          # so we use 'foo-bar' instead of 'foo/bar' to work around
          # the problem
          opts = {
            :marker => 'foo-bar',
            :prefix => 'foo-',
            :delimiter => '-',
            :limit => 10,
            :encoding => 'url'}

          query = opts.clone
          query['max-keys'] = query.delete(:limit)
          query['encoding-type'] = query.delete(:encoding)

          stub_request(:get, url).with(:query => query)

          @oss.list_object(bucket_name, opts)

          expect(WebMock).to have_requested(:get, url)
            .with(:body => "", :query => query)
        end

        it "should parse object and common prefixes response" do
          bucket_name = 'rubysdk-bucket'
          url = get_request_path(bucket_name)

          return_objects = ['hello', 'world', 'foo-bar']
          return_more = {
            :marker => 'foo-bar',
            :prefix => 'foo-',
            :delimiter => '-',
            :limit => 10,
            :encoding => 'url',
            :next_marker => 'foo-xxx',
            :truncated => true
          }

          opts = {
            :marker => 'foo-bar',
            :prefix => 'foo-',
            :delimiter => '-',
            :limit => 10,
            :encoding => 'url'
          }

          query = opts.clone
          query['max-keys'] = query.delete(:limit)
          query['encoding-type'] = query.delete(:encoding)

          stub_request(:get, url).with(:query => query).
            to_return(:body => mock_objects(return_objects, return_more))

          objects, more = @oss.list_object(bucket_name, opts)

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => query)

          expect(objects.map {|o| o.key}).to match_array(return_objects)
          expect(more).to eq(return_more)
        end

      end # list objects

      context "Delete bucket" do
      end

    end # Bucket

  end # OSS
end # Aliyun
