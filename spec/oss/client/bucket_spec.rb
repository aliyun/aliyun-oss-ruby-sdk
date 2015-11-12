# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'yaml'
require 'nokogiri'

module Aliyun
  module OSS

    describe Bucket do

      before :all do
        @endpoint = 'oss-cn-hangzhou.aliyuncs.com'
        id = 'xxx'
        key = 'yyy'
        @bucket_name = 'rubysdk-bucket'
        @bucket = Client.new(@endpoint, id, key).get_bucket(@bucket_name)
      end

      def bucket_url
        "#{@bucket_name}.#{@endpoint}"
      end

      def object_url(object)
        "#{@bucket_name}.#{@endpoint}/#{object}"
      end

      def mock_objects(objects, more = {})
        Nokogiri::XML::Builder.new do |xml|
          xml.ListBucketResult {
            {
              :prefix => 'Prefix',
              :delimiter => 'Delimiter',
              :limit => 'MaxKeys',
              :marker => 'Marker',
              :next_marker => 'NextMarker',
              :truncated => 'IsTruncated',
              :encoding => 'EncodingType'
            }.map do |k, v|
              xml.send(v, more[k]) if more[k] != nil
            end

            objects.each do |o|
              xml.Contents {
                xml.Key o.key
                xml.Size o.size
                xml.ETag o.etag
              }
            end

            (more[:common_prefixes] || []).each do |p|
              xml.CommonPrefixes {
                xml.Prefix p
              }
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

      def mock_acl(acl)
        Nokogiri::XML::Builder.new do |xml|
          xml.AccessControlPolicy {
            xml.Owner {
              xml.ID 'owner_id'
              xml.DisplayName 'owner_name'
            }

            xml.AccessControlList {
              xml.Grant acl
            }
          }
        end.to_xml
      end

      context "bucket operations" do
        it "should create bucket" do
          stub_request(:put, bucket_url)

          @bucket.create! :location => 'oss-cn-beijing'

          expect(WebMock).to have_requested(:put, bucket_url)
                         .with(:body => mock_location('oss-cn-beijing'))
        end

        it "should get acl" do
          query = {'acl' => ''}
          return_acl = ACL::PUBLIC_READ

          stub_request(:get, bucket_url)
            .with(:query => query)
            .to_return(:body => mock_acl(return_acl))

          acl = @bucket.acl

          expect(WebMock).to have_requested(:get, bucket_url)
            .with(:query => query, :body => nil)
          expect(acl).to eq(return_acl)
        end

        it "should set acl" do
          query = {'acl' => ''}

          stub_request(:put, bucket_url).with(:query => query)

          @bucket.acl = ACL::PUBLIC_READ

          expect(WebMock).to have_requested(:put, bucket_url)
            .with(:query => query, :body => nil)
        end

        it "should delete logging setting" do
          query = {'logging' => ''}

          stub_request(:delete, bucket_url).with(:query => query)

          @bucket.logging = {}

          expect(WebMock).to have_requested(:delete, bucket_url)
            .with(:query => query, :body => nil)
        end
      end # bucket operations

      context "object operations" do
        it "should list objects" do
          query_1 = {
            :prefix => 'list-',
            :delimiter => '-'
          }
          return_obj_1 = (1..5).map{ |i| Object.new(
            :key => "obj-#{i}",
            :size => 1024 * i,
            :etag => "etag-#{i}")}
          return_more_1 = {
            :next_marker => 'foo',
            :truncated => true,
            :common_prefixes => ['hello', 'world']
          }

          query_2 = {
            :prefix => 'list-',
            :delimiter => '-',
            :marker => 'foo'
          }
          return_obj_2 = (6..8).map{ |i| Object.new(
            :key => "obj-#{i}",
            :size => 1024 * i,
            :etag => "etag-#{i}")}
          return_more_2 = {
            :next_marker => 'bar',
            :truncated => false,
            :common_prefixes => ['rock', 'suck']
          }

          stub_request(:get, bucket_url)
            .with(:query => query_1)
            .to_return(:body => mock_objects(return_obj_1, return_more_1))

          stub_request(:get, bucket_url)
            .with(:query => query_2)
            .to_return(:body => mock_objects(return_obj_2, return_more_2))

          list = @bucket.list_objects :prefix => 'list-', :delimiter => '-'
          all = list.to_a

          expect(WebMock).to have_requested(:get, bucket_url)
                         .with(:query => query_1).times(1)
          expect(WebMock).to have_requested(:get, bucket_url)
                         .with(:query => query_2).times(1)

          objs = all.select{ |x| x.is_a?(Object) }
          common_prefixes = all.select{ |x| x.is_a?(String) }
          all_objs = (1..8).map{ |i| Object.new(
            :key => "obj-#{i}",
            :size => 1024 * i,
            :etag => "etag-#{i}")}
          expect(objs.map{ |o| o.to_s }).to match_array(all_objs.map{ |o| o.to_s })
          all_prefixes = ['hello', 'world', 'rock', 'suck']
          expect(common_prefixes).to match_array(all_prefixes)
        end

        it "should put object from file" do
          key = 'ruby'
          stub_request(:put, object_url(key))

          content = (1..10).map{ |i| i.to_s.rjust(9, '0') }.join("\n")
          File.open('/tmp/x', 'w'){ |f| f.write(content) }

          @bucket.put_object(key, :file => '/tmp/x')

          expect(WebMock).to have_requested(:put, object_url(key))
            .with(:body => content, :query => {})
        end

        it "should get object to file" do
          key = 'ruby'
          # 100 KB
          content = (1..1024).map{ |i| i.to_s.rjust(99, '0') }.join(",")

          stub_request(:get, object_url(key)).to_return(:body => content)

          @bucket.get_object(key, :file => '/tmp/x')

          expect(WebMock).to have_requested(:get, object_url(key))
                         .with(:body => nil, :query => {})
          expect(File.read('/tmp/x')).to eq(content)
        end

        it "should append object from file", :focus => true do
          key = 'ruby'
          query = {'append' => '', 'position' => 11}
          stub_request(:post, object_url(key)).with(:query => query)

          content = (1..10).map{ |i| i.to_s.rjust(9, '0') }.join("\n")
          content = "<html>" + content + "</html>"
          File.open('/tmp/x.html', 'w'){ |f| f.write(content) }

          @bucket.append_object(key, 11, :file => '/tmp/x.html')

          expect(WebMock).to have_requested(:post, object_url(key))
                         .with(:query => query, :body => content,
                               :headers => {'Content-Type' => 'text/html'})
        end
      end # object operations

    end # Bucket
  end # OSS
end # Aliyun
