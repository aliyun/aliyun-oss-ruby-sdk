# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'yaml'
require 'nokogiri'

module Aliyun
  module OSS

    describe "Object" do

      before :all do
        @endpoint = 'oss.aliyuncs.com'

        cred_file = "~/.oss.yml"
        cred = YAML.load(File.read(File.expand_path(cred_file)))
        Aliyun::OSS::Logging.set_log_level(Logger::DEBUG)

        @oss = Client.new(@endpoint, cred['id'], cred['key'])
        @bucket = 'rubysdk-bucket'
      end

      def get_request_path(object = nil)
        p = "#{@bucket}.#{@endpoint}/"
        p += CGI.escape(object) if object
        p
      end

      def get_resource_path(object)
        "/#{@bucket}/#{object}"
      end

      def mock_copy_object(last_modified, etag)
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.CopyObjectResult {
            xml.LastModified last_modified.to_s
            xml.ETag etag
          }
        end

        builder.to_xml
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

      def mock_delete(objects, opts = {})
        Nokogiri::XML::Builder.new do |xml|
          xml.Delete {
            xml.Quiet opts[:quiet]? true : false
            objects.each do |o|
              xml.Object {
                xml.Key o
              }
            end
          }
        end.to_xml
      end

      def mock_delete_result(deleted, opts = {})
        Nokogiri::XML::Builder.new do |xml|
          xml.DeleteResult {
            xml.EncodingType opts[:encoding] if opts[:encoding]
            deleted.each do |o|
              xml.Deleted {
                xml.Key o
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

      context "Put object" do

        it "should PUT to create object" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          stub_request(:put, url)

          content = "hello world"
          @oss.put_object(@bucket, object_name) do |c|
            c << content
          end

          expect(WebMock).to have_requested(:put, url)
            .with(:body => content, :query => {})
        end

        it "should PUT to create object from file" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          stub_request(:put, url)

          file = '/tmp/x'
          content = "hello world"
          File.open(file, 'w') {|f| f.write(content)}
          @oss.put_object_from_file(@bucket, object_name, file)

          expect(WebMock).to have_requested(:put, url)
            .with(:body => content, :query => {})
        end

        it "should raise Exception on error" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          code = 'NoSuchBucket'
          message = 'The bucket does not exist.'
          stub_request(:put, url).to_return(
            :status => 404, :body => mock_error(code, message))

          content = "hello world"
          expect {
            @oss.put_object(@bucket, object_name) do |c|
              c << content
            end
          }.to raise_error(Exception, message)

          expect(WebMock).to have_requested(:put, url)
            .with(:body => content, :query => {})
        end

        it "should use default content-type", :focus => true do
          object_name = 'ruby'
          url = get_request_path(object_name)
          stub_request(:put, url)

          @oss.put_object(@bucket, object_name) do |content|
            content << 'hello world' << HTTP::ENDS
          end

          expect(WebMock).to have_requested(:put, url)
            .with(:body => 'hello world',
                  :headers => {'Content-Type' => HTTP::DEFAULT_CONTENT_TYPE})
        end

        it "should use infer content-type from file" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          stub_request(:put, url)

          file = '/tmp/x.html'
          content = "<html>hello world</html>"
          File.open(file, 'w') {|f| f.write(content)}
          @oss.put_object_from_file(@bucket, object_name, file)

          expect(WebMock).to have_requested(:put, url)
            .with(:body => content,
                  :headers => {'Content-Type' => 'text/html'})
        end

        it "should use customized content-type" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          stub_request(:put, url)

          @oss.put_object(
            @bucket, object_name, :content_type => 'application/ruby'
          ) do |content|
            content << 'hello world' << HTTP::ENDS
          end

          expect(WebMock).to have_requested(:put, url)
            .with(:body => 'hello world',
                  :headers => {'Content-Type' => 'application/ruby'})
        end

        it "should support non-ascii object name" do
          object_name = '中国のruby'
          url = get_request_path(object_name)
          stub_request(:put, url)

          content = "hello world"
          @oss.put_object(@bucket, object_name) do |c|
            c << content
          end

          expect(WebMock).to have_requested(:put, url)
            .with(:body => content, :query => {})
        end
      end # put object

      context "Append object" do

        it "should POST to append object" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          query = {'append' => '', 'position' => 11}
          stub_request(:post, url).with(:query => query)

          content = "hello world"
          @oss.append_object(@bucket, object_name, 11) do |c|
            c << content
          end

          expect(WebMock).to have_requested(:post, url)
            .with(:body => content, :query => query)
        end

        it "should POST to append object from file" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          query = {'append' => '', 'position' => 11}
          stub_request(:post, url).with(:query => query)

          file = '/tmp/x'
          content = "hello world"
          File.open(file, 'w') {|f| f.write(content)}
          @oss.append_object_from_file(@bucket, object_name, 11, file)

          expect(WebMock).to have_requested(:post, url)
            .with(:body => content, :query => query)
        end

        it "should raise Exception on error" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          query = {'append' => '', 'position' => 11}
          code = 'ObjectNotAppendable'
          message = 'Normal object cannot be appended.'
          stub_request(:post, url).with(:query => query).
            to_return(:status => 409, :body => mock_error(code, message))

          content = "hello world"
          expect {
            @oss.append_object(@bucket, object_name, 11) do |c|
              c << content
            end
          }.to raise_error(Exception, message)

          expect(WebMock).to have_requested(:post, url)
            .with(:body => content, :query => query)
        end

        it "should use default content-type", :focus => true do
          object_name = 'ruby'
          url = get_request_path(object_name)
          query = {'append' => '', 'position' => 0}

          stub_request(:post, url).with(:query => query)

          @oss.append_object(@bucket, object_name, 0) do |content|
            content << 'hello world' << HTTP::ENDS
          end

          expect(WebMock).to have_requested(:post, url)
            .with(:body => 'hello world',
                  :query => query,
                  :headers => {'Content-Type' => HTTP::DEFAULT_CONTENT_TYPE})
        end

        it "should use infer content-type from file" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          query = {'append' => '', 'position' => 0}

          stub_request(:post, url).with(:query => query)

          file = '/tmp/x.html'
          content = "<html>hello world</html>"
          File.open(file, 'w') {|f| f.write(content)}
          @oss.append_object_from_file(@bucket, object_name, 0, file)

          expect(WebMock).to have_requested(:post, url)
            .with(:body => content,
                  :query => query,
                  :headers => {'Content-Type' => 'text/html'})
        end

        it "should use customized content-type" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          query = {'append' => '', 'position' => 0}

          stub_request(:post, url).with(:query => query)

          @oss.append_object(
            @bucket, object_name, 0, :content_type => 'application/ruby'
          ) do |content|
            content << 'hello world' << HTTP::ENDS
          end

          expect(WebMock).to have_requested(:post, url)
            .with(:body => 'hello world',
                  :query => query,
                  :headers => {'Content-Type' => 'application/ruby'})
        end
      end # append object

      context "Copy object" do

        it "should copy object" do
          src_object = 'ruby'
          dst_object = 'rails'
          url = get_request_path(dst_object)

          last_modified = Time.parse(Time.now.rfc822)
          etag = '0000'
          stub_request(:put, url).to_return(
            :body => mock_copy_object(last_modified, etag))

          result = @oss.copy_object(@bucket, src_object, dst_object)

          expect(WebMock).to have_requested(:put, url)
            .with(:body => nil, :headers => {
                    'x-oss-copy-source' => get_resource_path(src_object)})

          expect(result[:last_modified]).to eq(last_modified)
          expect(result[:etag]).to eq(etag)
        end

        it "should set acl and conditions when copy object" do
          src_object = 'ruby'
          dst_object = 'rails'
          url = get_request_path(dst_object)

          last_modified = Time.parse(Time.now.rfc822)
          etag = '0000'

          headers = {
            'x-oss-copy-source' => get_resource_path(src_object),
            'x-oss-object-acl' => Struct::ACL::PRIVATE,
            'x-oss-metadata-directive' => Struct::MetaDirective::REPLACE,
            'x-oss-copy-source-if-modified-since' => 'ms',
            'x-oss-copy-source-if-unmodified-since' => 'ums',
            'x-oss-copy-source-if-match' => 'me',
            'x-oss-copy-source-if-none-match' => 'ume'
          }
          stub_request(:put, url).to_return(
            :body => mock_copy_object(last_modified, etag))

          result = @oss.copy_object(
            @bucket, src_object, dst_object,
            {:acl => Struct::ACL::PRIVATE,
             :meta_directive => Struct::MetaDirective::REPLACE,
             :condition => {
               :if_modified_since => 'ms',
               :if_unmodified_since => 'ums',
               :if_match_etag => 'me',
               :if_unmatch_etag => 'ume'
             }
            })

          expect(WebMock).to have_requested(:put, url)
            .with(:body => nil, :headers => headers)

          expect(result[:last_modified]).to eq(last_modified)
          expect(result[:etag]).to eq(etag)
        end

        it "should raise Exception on error" do
          src_object = 'ruby'
          dst_object = 'rails'
          url = get_request_path(dst_object)

          code = 'EntityTooLarge'
          message = 'The object to copy is too large.'
          stub_request(:put, url).to_return(
            :status => 400, :body => mock_error(code, message))

          expect {
            @oss.copy_object(@bucket, src_object, dst_object)
          }.to raise_error(Exception, message)

          expect(WebMock).to have_requested(:put, url)
            .with(:body => nil, :headers => {
                  'x-oss-copy-source' => get_resource_path(src_object)})
        end
      end # copy object

      context "Get object", :focus => true do

        it "should GET to get object" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          return_content = "hello world"
          stub_request(:get, url).to_return(:body => return_content)

          content = ""
          @oss.get_object(@bucket, object_name) {|c| content << c}

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => {})

          expect(content).to eq(return_content)
        end

        it "should get object to file" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          return_content = "hello world"
          stub_request(:get, url).to_return(:body => return_content)

          file = '/tmp/x'
          @oss.get_object_to_file(@bucket, object_name, file)

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => {})

          expect(File.read(file)).to eq(return_content)
        end

        it "should raise Exception on error" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          code = 'NoSuchKey'
          message = 'The object does not exist'
          stub_request(:get, url).to_return(
            :status => 404, :body => mock_error(code, message))

          expect {
            @oss.get_object(@bucket, object_name) {|c| true}
          }.to raise_error(Exception, message)

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => {})
        end

        it "should get object range" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          stub_request(:get, url)

          @oss.get_object(@bucket, object_name, {:range => [0, 9]}) {}

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => {},
                  :headers => {
                    'Range' => '0-9'
                  })
        end

        it "should match modify time and etag" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          stub_request(:get, url)

          modified_since = Util.get_date
          unmodified_since = Util.get_date
          etag = 'xxxyyyzzz'
          not_etag = 'aaabbbccc'
          @oss.get_object(
            @bucket, object_name,
            {:condition => {
               :if_modified_since => modified_since,
               :if_unmodified_since => unmodified_since,
               :if_match_etag => etag,
               :if_unmatch_etag => not_etag}}) {}

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => {},
                  :headers => {
                    'If-Modified-Since' => modified_since,
                    'If-Unmodified-since' => unmodified_since,
                    'If-Match' => etag,
                    'If-None-Match' => not_etag})
        end

        it "should rewrite response headers" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          rewrites = {
               :content_type => 'ct',
               :content_language => 'cl',
               :expires => 'e',
               :cache_control => 'cc',
               :content_disposition => 'cd',
               :content_encoding => 'ce'
          }
          query = Hash[rewrites.map {|k, v| ["response-#{k.to_s.sub('_', '-')}", v]}]

          stub_request(:get, url).with(:query => query)

          @oss.get_object(@bucket, object_name, :rewrite => rewrites) {}

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => query)
        end
      end # Get object

      context "Delete object" do

        it "should DELETE to delete object" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          stub_request(:delete, url)

          @oss.delete_object(@bucket, object_name)

          expect(WebMock).to have_requested(:delete, url)
            .with(:body => nil, :query => {})
        end

        it "should raise Exception on error" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          code = 'NoSuchBucket'
          message = 'The bucket does not exist.'
          stub_request(:delete, url).to_return(
            :status => 404, :body => mock_error(code, message))

          expect {
            @oss.delete_object(@bucket, object_name)
          }.to raise_error(Exception, message)

          expect(WebMock).to have_requested(:delete, url)
            .with(:body => nil, :query => {})
        end

        it "should batch delete objects" do
          url = get_request_path
          query = {'delete' => '', 'encoding-type' => 'url'}

          object_names = (1..5).map do |i|
            "object-#{i}"
          end

          stub_request(:post, url)
            .with(:query => query)
            .to_return(:body => mock_delete_result(object_names))

          opts = {:quiet => false, :encoding => 'url'}
          deleted = @oss.batch_delete_objects(@bucket, object_names, opts)

          expect(WebMock).to have_requested(:post, url)
            .with(:query => query, :body => mock_delete(object_names, opts))
          expect(deleted).to match_array(object_names)
        end

        it "should decode object key in batch delete response" do
          url = get_request_path
          query = {'delete' => '', 'encoding-type' => 'url'}

          object_names = (1..5).map do |i|
            "对象-#{i}"
          end
          es_objects = (1..5).map do |i|
            CGI.escape "对象-#{i}"
          end
          opts = {:quiet => false, :encoding => 'url'}

          stub_request(:post, url)
            .with(:query => query)
            .to_return(:body => mock_delete_result(es_objects, opts))

          deleted = @oss.batch_delete_objects(@bucket, object_names, opts)

          expect(WebMock).to have_requested(:post, url)
            .with(:query => query, :body => mock_delete(object_names, opts))
          expect(deleted).to match_array(object_names)
        end
      end # delete object

      context "acl" do
        it "should update acl" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          query = {'acl' => ''}
          stub_request(:put, url).with(:query => query)

          @oss.update_object_acl(@bucket, object_name, Struct::ACL::PUBLIC_READ)

          expect(WebMock).to have_requested(:put, url)
            .with(:query => query,
                  :headers => {'x-oss-acl' => Struct::ACL::PUBLIC_READ},
                  :body => nil)
        end

        it "should get acl" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          query = {'acl' => ''}
          return_acl = Struct::ACL::PUBLIC_READ

          stub_request(:get, url)
            .with(:query => query)
            .to_return(:body => mock_acl(return_acl))

          acl = @oss.get_object_acl(@bucket, object_name)

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => query)
          expect(acl).to eq(return_acl)
        end
      end # acl

      context "cors" do
        it "should get object cors" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          return_rule = Struct::CORSRule.new(
            :allowed_origins => 'origin',
            :allowed_methods => 'PUT',
            :allowed_headers => 'Authorization',
            :expose_headers => 'x-oss-test',
            :max_age_seconds => 10
          )
          stub_request(:options, url).to_return(
            :headers => {
              'Access-Control-Allow-Origin' => return_rule.allowed_origins,
              'Access-Control-Allow-Methods' => return_rule.allowed_methods,
              'Access-Control-Allow-Headers' => return_rule.allowed_headers,
              'Access-Control-Expose-Headers' => return_rule.expose_headers,
              'Access-Control-Max-Age' => return_rule.max_age_seconds
            }
          )

          rule = @oss.get_object_cors(
            @bucket, object_name, 'origin', 'PUT', ['Authorization'])

          expect(WebMock).to have_requested(:options, url)
            .with(:body => nil, :query => {})
          expect(rule.to_s).to eq(return_rule.to_s)
        end
      end # cors

    end # Object

  end # OSS
end # Aliyun
