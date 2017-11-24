# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'yaml'
require 'nokogiri'

module Aliyun
  module OSS

    describe "Bucket" do

      # before :all do
      #   @endpoint = 'oss.aliyuncs.com'
      #   @protocol = Protocol.new(
      #     Config.new(:endpoint => @endpoint,
      #                :access_key_id => 'xxx', :access_key_secret => 'yyy'))
      #   @bucket = 'rubysdk-bucket'
      # end
      before :all do
        @endpoint = 'oss.aliyuncs.com'
        @protocol = Protocol.new(
            Config.new(:endpoint => @endpoint,
                       :access_key_id => 'xxx', :access_key_secret => 'yyy'))
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

      def mock_storage_class(storage_class)
        Nokogiri::XML::Builder.new do |xml|
          xml.CreateBucketConfiguration {
            xml.StorageClass storage_class
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
            if opts.enabled?
              xml.LoggingEnabled {
                xml.TargetBucket opts.target_bucket
                xml.TargetPrefix opts.target_prefix
              }
            end
          }
        end.to_xml
      end

      def mock_website(opts)
        Nokogiri::XML::Builder.new do |xml|
          xml.WebsiteConfiguration {
            xml.IndexDocument {
              xml.Suffix opts.index
            }
            if opts.error
              xml.ErrorDocument {
                xml.Key opts.error
              }
            end
          }
        end.to_xml
      end

      def mock_referer(opts)
        Nokogiri::XML::Builder.new do |xml|
          xml.RefererConfiguration {
            xml.AllowEmptyReferer opts.allow_empty?
            xml.RefererList {
              opts.whitelist.each do |r|
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
                xml.Status r.enabled? ? 'Enabled' : 'Disabled'
                xml.Prefix r.prefix
                if r.expiry
                  xml.Expiration {
                    if r.expiry.is_a?(Date)
                      if r.is_created_before_date?
                        xml.CreatedBeforeDate Time.utc(
                            r.expiry.year, r.expiry.month, r.expiry.day)
                                                  .iso8601.sub('Z', '.000Z')
                      else
                        xml.Date Time.utc(
                            r.expiry.year, r.expiry.month, r.expiry.day)
                                     .iso8601.sub('Z', '.000Z')
                      end
                    else
                      xml.Days r.expiry.to_i
                    end
                  }
                end
                if r.abort_multipart_upload
                    xml.AbortMultipartUpload {
                      if r.abort_multipart_upload.is_a?(Date)
                        xml.CreatedBeforeDate Time.utc(
                            r.abort_multipart_upload.year, r.abort_multipart_upload.month,
                            r.abort_multipart_upload.day).iso8601.sub('Z', '.000Z')
                      elsif r.abort_multipart_upload.is_a?(Fixnum)
                        xml.Days r.expiry
                      else
                        fail ClientError, "Expiry must be a Date or Fixnum."
                      end
                    }
                end
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
        Nokogiri::XML::Builder.new do |xml|
          xml.Error {
            xml.Code code
            xml.Message message
            xml.RequestId '0000'
          }
        end.to_xml
      end

      def err(msg, reqid = '0000')
        "#{msg} RequestId: #{reqid}"
      end

      def mock_bucket_info()
        Nokogiri::XML::Builder.new do |xml|
          xml.BucketInfo {
            xml.Bucket {
              xml.CreationDate '2017-11-23T05:59:56.000Z'
              xml.ExtranetEndpoint 'oss-cn-hangzhou.aliyuncs.com'
              xml.IntranetEndpoint 'oss-cn-hangzhou-internal.aliyuncs.com'
              xml.Location 'oss-cn-hangzhou'
              xml.Name @bucket
              xml.StorageClass 'Standard'
              xml.Owner {
                xml.DisplayName '1999610231449665'
                xml.ID '1999610231449665'
              }
              xml.AccessControlList {
                xml.Grant 'private'
              }
            }
          }
        end.to_xml
      end

      def mock_bucket_stat()
        Nokogiri::XML::Builder.new do |xml|
          xml.BucketStat {
            xml.Storage '33017908'
            xml.ObjectCount '140'
            xml.MultipartUploadCount '5'
          }
        end.to_xml
      end

      context "Create bucket" do

        it "should PUT to create bucket" do
          stub_request(:put, request_path)

          @protocol.create_bucket(@bucket)

          expect(WebMock).to have_requested(:put, request_path)
            .with(:body => nil, :query => {})
        end

        it "should set location when create bucket" do
          location = 'oss-cn-hangzhou'

          stub_request(:put, request_path).with(:body => mock_location(location))

          @protocol.create_bucket(@bucket, :location => 'oss-cn-hangzhou')

          expect(WebMock).to have_requested(:put, request_path)
                                 .with(:body => mock_location(location), :query => {})
        end

        it "should set storage_class when create bucket" do
          storage_class = 'Archive'

          stub_request(:put, request_path).with(:body => mock_storage_class(storage_class))

          @protocol.create_bucket(@bucket, :storage_class => 'Archive')

          expect(WebMock).to have_requested(:put, request_path)
                                 .with(:body => mock_storage_class(storage_class), :query => {})
        end
      end # create bucket

      context "Get Bucket Info" do
        it "should get bucket info" do
          query = {'bucketInfo' => nil}
          stub_request(:get, request_path).with(:query => query).
              to_return(:body => mock_bucket_info())

          bucket_info = @protocol.get_bucket_info(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
                                 .with(:query => query)

          expect(bucket_info.name).to eq(@bucket)
          expect(bucket_info.creation_date).to eq('2017-11-23T05:59:56.000Z')
          expect(bucket_info.extranet_endpoint).to eq('oss-cn-hangzhou.aliyuncs.com')
          expect(bucket_info.intranet_endpoint).to eq('oss-cn-hangzhou-internal.aliyuncs.com')
          expect(bucket_info.location).to eq('oss-cn-hangzhou')
          expect(bucket_info.owner_display_name).to eq('1999610231449665')
          expect(bucket_info.owner_id).to eq('1999610231449665')
          expect(bucket_info.grant).to eq('private')
          expect(bucket_info.storage_class).to eq('Standard')

        end
      end # get bucket info

      context "Get Bucket Stat" do
        it "should get bucket stat" do
          query = {'stat' => nil}
          stub_request(:get, request_path).with(:query => query).
              to_return(:body => mock_bucket_stat())

          bucket_stat = @protocol.get_bucket_stat(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
                                 .with(:query => query)

          expect(bucket_stat.storage).to eq('33017908')
          expect(bucket_stat.object_count).to eq('140')
          expect(bucket_stat.multipart_upload_count).to eq('5')

        end
      end # get bucket stat

      context "List objects" do

        it "should list all objects" do
          stub_request(:get, request_path)

          @protocol.list_objects(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:body => nil, :query => {})
        end

        it "should parse object response" do
          return_objects = ['hello', 'world', 'foo/bar']
          stub_request(:get, request_path)
            .to_return(:body => mock_objects(return_objects))

          objects, more = @protocol.list_objects(@bucket)

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
            :encoding => KeyEncoding::URL}

          query = opts.clone
          query['max-keys'] = query.delete(:limit)
          query['encoding-type'] = query.delete(:encoding)

          stub_request(:get, request_path).with(:query => query)

          @protocol.list_objects(@bucket, opts)

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
            :encoding => KeyEncoding::URL,
            :next_marker => 'foo-xxx',
            :truncated => true,
            :common_prefixes => ['foo/bar/', 'foo/xxx/']
          }

          opts = {
            :marker => 'foo-bar',
            :prefix => 'foo-',
            :delimiter => '-',
            :limit => 10,
            :encoding => KeyEncoding::URL
          }

          query = opts.clone
          query['max-keys'] = query.delete(:limit)
          query['encoding-type'] = query.delete(:encoding)

          stub_request(:get, request_path).with(:query => query).
            to_return(:body => mock_objects(return_objects, return_more))

          objects, more = @protocol.list_objects(@bucket, opts)

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
            :encoding => KeyEncoding::URL,
            :next_marker => '西湖のruby',
            :truncated => true,
            :common_prefixes => ['玉泉のruby', '苏堤のruby']
          }

          es_objects = [CGI.escape('中国のruby'), 'world', 'foo/bar']
          es_more = {
            :marker => CGI.escape('杭州のruby'),
            :prefix => 'foo-',
            :delimiter => CGI.escape('分隔のruby'),
            :limit => 10,
            :encoding => KeyEncoding::URL,
            :next_marker => CGI.escape('西湖のruby'),
            :truncated => true,
            :common_prefixes => [CGI.escape('玉泉のruby'), CGI.escape('苏堤のruby')]
          }

          stub_request(:get, request_path)
            .to_return(:body => mock_objects(es_objects, es_more))

          objects, more = @protocol.list_objects(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:body => nil, :query => {})

          expect(objects.map {|o| o.key}).to match_array(return_objects)
          expect(more).to eq(return_more)
        end
      end # list objects

      context "Delete bucket" do

        it "should send DELETE reqeust" do
          stub_request(:delete, request_path)

          @protocol.delete_bucket(@bucket)

          expect(WebMock).to have_requested(:delete, request_path)
            .with(:body => nil, :query => {})
        end

        it "should raise Exception on error" do
          code = "NoSuchBucket"
          message = "The bucket to delete does not exist."

          stub_request(:delete, request_path).to_return(
            :status => 404, :body => mock_error(code, message))

          expect {
            @protocol.delete_bucket(@bucket)
          }.to raise_error(ServerError, err(message))
        end
      end # delete bucket

      context "acl, logging, website, referer, lifecycle" do
        it "should update acl" do
          query = {'acl' => nil}
          stub_request(:put, request_path).with(:query => query)

          @protocol.put_bucket_acl(@bucket, ACL::PUBLIC_READ)

          expect(WebMock).to have_requested(:put, request_path)
            .with(:query => query, :body => nil)
        end

        it "should get acl" do
          query = {'acl' => nil}
          return_acl = ACL::PUBLIC_READ
          stub_request(:get, request_path)
            .with(:query => query)
            .to_return(:body => mock_acl(return_acl))

          acl = @protocol.get_bucket_acl(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:query => query, :body => nil)
          expect(acl).to eq(return_acl)
        end

        it "should enable logging" do
          query = {'logging' => nil}
          stub_request(:put, request_path).with(:query => query)

          logging_opts = BucketLogging.new(
            :enable => true,
            :target_bucket => 'target-bucket', :target_prefix => 'foo')
          @protocol.put_bucket_logging(@bucket, logging_opts)

          expect(WebMock).to have_requested(:put, request_path)
            .with(:query => query, :body => mock_logging(logging_opts))
        end

        it "should disable logging" do
          query = {'logging' => nil}
          stub_request(:put, request_path).with(:query => query)

          logging_opts = BucketLogging.new(:enable => false)
          @protocol.put_bucket_logging(@bucket, logging_opts)

          expect(WebMock).to have_requested(:put, request_path)
            .with(:query => query, :body => mock_logging(logging_opts))
        end

        it "should get logging" do
          query = {'logging' => nil}
          logging_opts = BucketLogging.new(
            :enable => true,
            :target_bucket => 'target-bucket', :target_prefix => 'foo')

          stub_request(:get, request_path)
            .with(:query => query)
            .to_return(:body => mock_logging(logging_opts))

          logging = @protocol.get_bucket_logging(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:query => query, :body => nil)
          expect(logging.to_s).to eq(logging_opts.to_s)
        end

        it "should delete logging" do
          query = {'logging' => nil}
          stub_request(:delete, request_path).with(:query => query)

          @protocol.delete_bucket_logging(@bucket)

          expect(WebMock).to have_requested(:delete, request_path)
            .with(:query => query, :body => nil)
        end

        it "should update website" do
          query = {'website' => nil}
          stub_request(:put, request_path).with(:query => query)

          website_opts = BucketWebsite.new(
            :enable => true, :index => 'index.html', :error => 'error.html')
          @protocol.put_bucket_website(@bucket, website_opts)

          expect(WebMock).to have_requested(:put, request_path)
            .with(:query => query, :body => mock_website(website_opts))
        end

        it "should get website" do
          query = {'website' => nil}
          website_opts = BucketWebsite.new(
            :enable => true, :index => 'index.html', :error => 'error.html')

          stub_request(:get, request_path)
            .with(:query => query)
            .to_return(:body => mock_website(website_opts))

          opts = @protocol.get_bucket_website(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:query => query, :body => nil)
          expect(opts.to_s).to eq(website_opts.to_s)
        end

        it "should delete website" do
          query = {'website' => nil}
          stub_request(:delete, request_path).with(:query => query)

          @protocol.delete_bucket_website(@bucket)

          expect(WebMock).to have_requested(:delete, request_path)
            .with(:query => query, :body => nil)
        end

        it "should update referer" do
          query = {'referer' => nil}
          stub_request(:put, request_path).with(:query => query)

          referer_opts = BucketReferer.new(
            :allow_empty => true, :whitelist => ['xxx', 'yyy'])
          @protocol.put_bucket_referer(@bucket, referer_opts)

          expect(WebMock).to have_requested(:put, request_path)
            .with(:query => query, :body => mock_referer(referer_opts))
        end

        it "should get referer" do
          query = {'referer' => nil}
          referer_opts = BucketReferer.new(
            :allow_empty => true, :whitelist => ['xxx', 'yyy'])

          stub_request(:get, request_path)
            .with(:query => query)
            .to_return(:body => mock_referer(referer_opts))

          opts = @protocol.get_bucket_referer(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:query => query, :body => nil)
          expect(opts.to_s).to eq(referer_opts.to_s)
        end

        it "should update lifecycle" do
          query = {'lifecycle' => nil}
          stub_request(:put, request_path).with(:query => query)

          rules = (1..5).map do |i|
            LifeCycleRule.new(
              :id => i, :enable => i % 2 == 0, :prefix => "foo#{i}",
              :expiry => (i % 2 == 1 ? Date.today : 10 + i),
              :is_created_before_date => (i % 4 ==1 ? true : false))
          end

          @protocol.put_bucket_lifecycle(@bucket, rules)

          expect(WebMock).to have_requested(:put, request_path)
            .with(:query => query, :body => mock_lifecycle(rules))
        end

        it "should get lifecycle" do
          query = {'lifecycle' => nil}
          return_rules = (1..5).map do |i|
            LifeCycleRule.new(
              :id => i, :enable => i % 2 == 0, :prefix => "foo#{i}",
              :expiry => (i % 2 == 1 ? Date.today : 10 + i),
              :is_created_before_date => i % 4 == 1)
          end

          stub_request(:get, request_path)
            .with(:query => query)
            .to_return(:body => mock_lifecycle(return_rules))

          rules = @protocol.get_bucket_lifecycle(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:query => query, :body => nil)
          expect(rules.map(&:to_s)).to match_array(return_rules.map(&:to_s))
        end

        it "should delete lifecycle" do
          query = {'lifecycle' => nil}
          stub_request(:delete, request_path).with(:query => query)

          @protocol.delete_bucket_lifecycle(@bucket)

          expect(WebMock).to have_requested(:delete, request_path)
            .with(:query => query, :body => nil)
        end

        it "should set cors" do
          query = {'cors' => nil}
          stub_request(:put, request_path).with(:query => query)

          rules = (1..5).map do |i|
            CORSRule.new(
              :allowed_origins => (1..3).map {|x| "origin-#{x}"},
              :allowed_methods => ['PUT', 'GET'],
              :allowed_headers => (1..3).map {|x| "header-#{x}"},
              :expose_headers => (1..3).map {|x| "header-#{x}"})
          end
          @protocol.set_bucket_cors(@bucket, rules)

          expect(WebMock).to have_requested(:put, request_path)
            .with(:query => query, :body => mock_cors(rules))
        end

        it "should get cors" do
          query = {'cors' => nil}
          return_rules = (1..5).map do |i|
            CORSRule.new(
              :allowed_origins => (1..3).map {|x| "origin-#{x}"},
              :allowed_methods => ['PUT', 'GET'],
              :allowed_headers => (1..3).map {|x| "header-#{x}"},
              :expose_headers => (1..3).map {|x| "header-#{x}"})
          end

          stub_request(:get, request_path)
            .with(:query => query)
            .to_return(:body => mock_cors(return_rules))

          rules = @protocol.get_bucket_cors(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:query => query, :body => nil)
          expect(rules.map(&:to_s)).to match_array(return_rules.map(&:to_s))
        end

        it "should delete cors" do
          query = {'cors' => nil}

          stub_request(:delete, request_path).with(:query => query)

          @protocol.delete_bucket_cors(@bucket)
          expect(WebMock).to have_requested(:delete, request_path)
            .with(:query => query, :body => nil)
        end

      end # acl, logging, cors, etc

      context "crc" do
        it "should download crc enable equal config setting" do
          protocol = Protocol.new(
                      Config.new(:endpoint => @endpoint,
                      :access_key_id => 'xxx', :access_key_secret => 'yyy',
                      :download_crc_enable => 'true'))
          expect(protocol.download_crc_enable).to eq(true)

          protocol = Protocol.new(
                      Config.new(:endpoint => @endpoint,
                      :access_key_id => 'xxx', :access_key_secret => 'yyy',
                      :download_crc_enable => true))
          expect(protocol.download_crc_enable).to eq(true)

          protocol = Protocol.new(
                      Config.new(:endpoint => @endpoint,
                      :access_key_id => 'xxx', :access_key_secret => 'yyy',
                      :download_crc_enable => 'false'))
          expect(protocol.download_crc_enable).to eq(false)

          protocol = Protocol.new(
                      Config.new(:endpoint => @endpoint,
                      :access_key_id => 'xxx', :access_key_secret => 'yyy',
                      :download_crc_enable => false))
          expect(protocol.download_crc_enable).to eq(false)
        end

        it "should upload crc enable equal config setting" do
          protocol = Protocol.new(
                      Config.new(:endpoint => @endpoint,
                      :access_key_id => 'xxx', :access_key_secret => 'yyy',
                      :upload_crc_enable => 'true'))
          expect(protocol.upload_crc_enable).to eq(true)

          protocol = Protocol.new(
                      Config.new(:endpoint => @endpoint,
                      :access_key_id => 'xxx', :access_key_secret => 'yyy',
                      :upload_crc_enable => true))
          expect(protocol.upload_crc_enable).to eq(true)

          protocol = Protocol.new(
                      Config.new(:endpoint => @endpoint,
                      :access_key_id => 'xxx', :access_key_secret => 'yyy',
                      :upload_crc_enable => 'false'))
          expect(protocol.upload_crc_enable).to eq(false)

          protocol = Protocol.new(
                      Config.new(:endpoint => @endpoint,
                      :access_key_id => 'xxx', :access_key_secret => 'yyy',
                      :upload_crc_enable => false))
          expect(protocol.upload_crc_enable).to eq(false)
        end
      end # crc

    end # Bucket

  end # OSS
end # Aliyun
