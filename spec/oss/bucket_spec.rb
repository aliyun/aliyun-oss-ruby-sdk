# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'yaml'
require 'nokogiri'

module Aliyun
  module OSS

    describe "Bucket" do

      before :all do
        @endpoint = 'oss.aliyuncs.com'

        creds_file = "~/.oss.yml"
        creds = YAML.load(File.read(File.expand_path(creds_file)))
        Aliyun::OSS::Logging.set_log_level(Logger::DEBUG)

        Config.set_endpoint(@endpoint)
        Config.set_credentials(creds['id'], creds['key'])
        @bucket = 'rubysdk-bucket'
      end

      def request_path
        @bucket + "." + @endpoint
      end

      def mock_location(location)
        Nokogiri::XML::Builder.new do |xml|
          xml.CreateBucketConfiguration {
            xml.LocationConstraint location
          }
        end.to_xml
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

      def mock_logging(opts)
        Nokogiri::XML::Builder.new do |xml|
          xml.BucketLoggingStatus {
            if opts[:enable]
              xml.LoggingEnabled {
                xml.TargetBucket opts[:target_bucket]
                xml.TargetPrefix opts[:prefix]
              }
            end
          }
        end.to_xml
      end

      def mock_website(opts)
        Nokogiri::XML::Builder.new do |xml|
          xml.WebsiteConfiguration {
            xml.IndexDocument {
              xml.Suffix opts[:index]
            }
            if opts[:error]
              xml.ErrorDocument {
                xml.Key opts[:error]
              }
            end
          }
        end.to_xml
      end

      def mock_referer(opts)
        Nokogiri::XML::Builder.new do |xml|
          xml.RefererConfiguration {
            xml.AllowEmptyReferer opts[:allow_empty]
            xml.RefererList {
              opts[:referers].each do |r|
                xml.Referer r
              end
            }
          }
        end.to_xml
      end

      def mock_lifecycle(rules)
        Nokogiri::XML::Builder.new do |xml|
          xml.LifecycleConfiguration {
            rules.each do |r|
              xml.Rule {
                xml.ID r.id if r.id
                xml.Status r.enabled ? 'Enabled' : 'Disabled'
                xml.Prefix r.prefix
                xml.Expiration {
                  if r.expiry.is_a?(Time)
                    xml.Date r.expiry.iso8601
                  else
                    xml.Days r.expiry.to_i
                  end
                }
              }
            end
          }
        end.to_xml
      end

      def mock_cors(rules)
        Nokogiri::XML::Builder.new do |xml|
          xml.CORSConfiguration {
            rules.each do |r|
              xml.CORSRule {
                r.allowed_origins.each do |x|
                  xml.AllowedOrigin x
                end
                r.allowed_methods.each do |x|
                  xml.AllowedMethod x
                end
                r.allowed_headers.each do |x|
                  xml.AllowedHeader x
                end
                r.expose_headers.each do |x|
                  xml.ExposeHeader x
                end
                xml.MaxAgeSeconds r.max_age_seconds if r.max_age_seconds
              }
            end
          }
        end.to_xml
      end

      def mock_error(code, message)
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.Error {
            xml.Code code
            xml.Message message
            xml.RequestId '0000'
          }
        end

        builder.to_xml
      end

      context "Create bucket" do

        it "should PUT to create bucket" do
          stub_request(:put, request_path)

          Protocol.create_bucket(@bucket)

          expect(WebMock).to have_requested(:put, request_path)
            .with(:body => nil, :query => {})
        end

        it "should set location when create bucket" do
          location = 'oss-cn-hangzhou'

          stub_request(:put, request_path).with(:body => mock_location(location))

          Protocol.create_bucket(@bucket, :location => 'oss-cn-hangzhou')

          expect(WebMock).to have_requested(:put, request_path)
            .with(:body => mock_location(location), :query => {})
        end
      end # create bucket

      context "List objects" do

        it "should list all objects" do
          stub_request(:get, request_path)

          Protocol.list_objects(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:body => nil, :query => {})
        end

        it "should parse object response" do
          return_objects = ['hello', 'world', 'foo/bar']
          stub_request(:get, request_path)
            .to_return(:body => mock_objects(return_objects))

          objects, more = Protocol.list_objects(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:body => nil, :query => {})

          expect(objects.map {|o| o.key}).to match_array(return_objects)
          expect(more).to be_empty
        end

        it "should list objects with prefix & delimiter" do
          # Webmock cannot capture the request_path encoded query parameters,
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

          stub_request(:get, request_path).with(:query => query)

          Protocol.list_objects(@bucket, opts)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:body => "", :query => query)
        end

        it "should parse object and common prefixes response" do
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

          stub_request(:get, request_path).with(:query => query).
            to_return(:body => mock_objects(return_objects, return_more))

          objects, more = Protocol.list_objects(@bucket, opts)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:body => nil, :query => query)

          expect(objects.map {|o| o.key}).to match_array(return_objects)
          expect(more).to eq(return_more)
        end

        it "should decode object key" do
          return_objects = ['中国のruby', 'world', 'foo/bar']
          return_more = {
            :marker => '杭州のruby',
            :prefix => 'foo-',
            :delimiter => '分隔のruby',
            :limit => 10,
            :encoding => 'url',
            :next_marker => '西湖のruby',
            :truncated => true
          }

          es_objects = [CGI.escape('中国のruby'), 'world', 'foo/bar']
          es_more = {
            :marker => CGI.escape('杭州のruby'),
            :prefix => 'foo-',
            :delimiter => CGI.escape('分隔のruby'),
            :limit => 10,
            :encoding => 'url',
            :next_marker => CGI.escape('西湖のruby'),
            :truncated => true
          }

          stub_request(:get, request_path)
            .to_return(:body => mock_objects(es_objects, es_more))

          objects, more = Protocol.list_objects(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:body => nil, :query => {})

          expect(objects.map {|o| o.key}).to match_array(return_objects)
          expect(more).to eq(return_more)
        end
      end # list objects

      context "Delete bucket" do

        it "should send DELETE reqeust" do
          stub_request(:delete, request_path)

          Protocol.delete_bucket(@bucket)

          expect(WebMock).to have_requested(:delete, request_path)
            .with(:body => nil, :query => {})
        end

        it "should raise Exception on error" do
          code = "NoSuchBucket"
          message = "The bucket to delete does not exist."

          stub_request(:delete, request_path).to_return(
            :status => 404, :body => mock_error(code, message))

          expect {
            Protocol.delete_bucket(@bucket)
          }.to raise_error(Exception, message)
        end
      end # delete bucket

      context "acl, logging, website, referer, lifecycle" do
        it "should update acl" do
          query = {'acl' => ''}
          stub_request(:put, request_path).with(:query => query)

          Protocol.update_bucket_acl(@bucket, Struct::ACL::PUBLIC_READ)

          expect(WebMock).to have_requested(:put, request_path)
            .with(:query => query, :body => nil)
        end

        it "should get acl" do
          query = {'acl' => ''}
          return_acl = Struct::ACL::PUBLIC_READ
          stub_request(:get, request_path)
            .with(:query => query)
            .to_return(:body => mock_acl(return_acl))

          acl = Protocol.get_bucket_acl(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:query => query, :body => nil)
          expect(acl).to eq(return_acl)
        end

        it "should enable logging" do
          query = {'logging' => ''}
          stub_request(:put, request_path).with(:query => query)

          logging_opts = {
            :enable => true, :target_bucket => 'target-bucket', :prefix => 'foo'
          }
          Protocol.update_bucket_logging(@bucket, logging_opts)

          expect(WebMock).to have_requested(:put, request_path)
            .with(:query => query, :body => mock_logging(logging_opts))
        end

        it "should disable logging" do
          query = {'logging' => ''}
          stub_request(:put, request_path).with(:query => query)

          logging_opts = {:enable => false}
          Protocol.update_bucket_logging(@bucket, logging_opts)

          expect(WebMock).to have_requested(:put, request_path)
            .with(:query => query, :body => mock_logging(logging_opts))
        end

        it "should get logging" do
          query = {'logging' => ''}
          logging_opts = {
            :enable => true, :target_bucket => 'target-bucket', :prefix => 'foo'
          }
          stub_request(:get, request_path)
            .with(:query => query)
            .to_return(:body => mock_logging(logging_opts))

          opts = Protocol.get_bucket_logging(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:query => query, :body => nil)
          expect(opts).to eq(logging_opts)
        end

        it "should delete logging" do
          query = {'logging' => ''}
          stub_request(:delete, request_path).with(:query => query)

          Protocol.delete_bucket_logging(@bucket)

          expect(WebMock).to have_requested(:delete, request_path)
            .with(:query => query, :body => nil)
        end

        it "should update website" do
          query = {'website' => ''}
          stub_request(:put, request_path).with(:query => query)

          website_opts = {:index => 'index.html', :error => 'error.html'}
          Protocol.update_bucket_website(@bucket, website_opts)

          expect(WebMock).to have_requested(:put, request_path)
            .with(:query => query, :body => mock_website(website_opts))
        end

        it "should get website" do
          query = {'website' => ''}
          website_opts = {:index => 'index.html', :error => 'error.html'}

          stub_request(:get, request_path)
            .with(:query => query)
            .to_return(:body => mock_website(website_opts))

          opts = Protocol.get_bucket_website(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:query => query, :body => nil)
          expect(opts).to eq(website_opts)
        end

        it "should delete website" do
          query = {'website' => ''}
          stub_request(:delete, request_path).with(:query => query)

          Protocol.delete_bucket_website(@bucket)

          expect(WebMock).to have_requested(:delete, request_path)
            .with(:query => query, :body => nil)
        end

        it "should update referer" do
          query = {'referer' => ''}
          stub_request(:put, request_path).with(:query => query)

          referer_opts = {:allow_empty => true, :referers => ['xxx', 'yyy']}
          Protocol.update_bucket_referer(@bucket, referer_opts)

          expect(WebMock).to have_requested(:put, request_path)
            .with(:query => query, :body => mock_referer(referer_opts))
        end

        it "should get referer" do
          query = {'referer' => ''}
          referer_opts = {:allow_empty => true, :referers => ['xxx', 'yyy']}

          stub_request(:get, request_path)
            .with(:query => query)
            .to_return(:body => mock_referer(referer_opts))

          opts = Protocol.get_bucket_referer(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:query => query, :body => nil)
          expect(opts).to eq(referer_opts)
        end

        it "should update lifecycle" do
          query = {'lifecycle' => ''}
          stub_request(:put, request_path).with(:query => query)

          rules = (1..5).map do |i|
            Struct::LifeCycleRule.new(
              :id => i, :enabled => i % 2 == 0, :prefix => "foo#{i}",
              :expiry => (i % 2 == 1 ? Time.now : 10 + i))
          end

          Protocol.update_bucket_lifecycle(@bucket, rules)

          expect(WebMock).to have_requested(:put, request_path)
            .with(:query => query, :body => mock_lifecycle(rules))
        end

        it "should get lifecycle" do
          query = {'lifecycle' => ''}
          return_rules = (1..5).map do |i|
            Struct::LifeCycleRule.new(
              :id => i, :enabled => i % 2 == 0, :prefix => "foo#{i}",
              :expiry => (i % 2 == 1 ? Time.now.iso8601 : 10 + i))
          end

          stub_request(:get, request_path)
            .with(:query => query)
            .to_return(:body => mock_lifecycle(return_rules))

          rules = Protocol.get_bucket_lifecycle(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:query => query, :body => nil)
          expect(rules.map {|x| x.id}).to eq(return_rules.map {|x| x.id})
        end

        it "should delete lifecycle" do
          query = {'lifecycle' => ''}
          stub_request(:delete, request_path).with(:query => query)

          Protocol.delete_bucket_lifecycle(@bucket)

          expect(WebMock).to have_requested(:delete, request_path)
            .with(:query => query, :body => nil)
        end

        it "should set cors" do
          query = {'cors' => ''}
          stub_request(:put, request_path).with(:query => query)

          rules = (1..5).map do |i|
            Struct::CORSRule.new(
              :allowed_origins => (1..3).map {|x| "origin-#{x}"},
              :allowed_methods => ['PUT', 'GET'],
              :allowed_headers => (1..3).map {|x| "header-#{x}"},
              :expose_headers => (1..3).map {|x| "header-#{x}"})
          end
          Protocol.set_bucket_cors(@bucket, rules)

          expect(WebMock).to have_requested(:put, request_path)
            .with(:query => query, :body => mock_cors(rules))
        end

        it "should get cors" do
          query = {'cors' => ''}
          return_rules = (1..5).map do |i|
            Struct::CORSRule.new(
              :allowed_origins => (1..3).map {|x| "origin-#{x}"},
              :allowed_methods => ['PUT', 'GET'],
              :allowed_headers => (1..3).map {|x| "header-#{x}"},
              :expose_headers => (1..3).map {|x| "header-#{x}"})
          end

          stub_request(:get, request_path)
            .with(:query => query)
            .to_return(:body => mock_cors(return_rules))

          rules = Protocol.get_bucket_cors(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:query => query, :body => nil)
          expect(rules.map {|r| r.to_s}.join("; ")).to eq(return_rules.map {|r| r.to_s}.join("; "))
        end

        it "should delete cors" do
          query = {'cors' => ''}

          stub_request(:delete, request_path).with(:query => query)

          Protocol.delete_bucket_cors(@bucket)
          expect(WebMock).to have_requested(:delete, request_path)
            .with(:query => query, :body => nil)
        end

      end # acl, logging, cors, etc

    end # Bucket

  end # OSS
end # Aliyun
