# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'yaml'
require 'nokogiri'

module Aliyun
  module OSS

    describe "Service" do
      before :all do
        cred_file = "~/.oss.yml"
        cred = YAML.load(File.read(File.expand_path(cred_file)))
        Aliyun::OSS::Logging.set_log_level(Logger::DEBUG)

        @host = 'oss.aliyuncs.com'
        @oss = Client.new(@host, cred['id'], cred['key'])

        @all_buckets = []
        (1..10).each do |i|
          name = "rubysdk-bucket-#{i.to_s.rjust(3, '0')}"
          @all_buckets << Bucket.new(name, 'oss-cn-hangzhou', Time.now)
        end
      end

      # 生成list_bucket返回的响应，包含bucket列表和more信息
      def mock_response(buckets, more)
        doc = Nokogiri::XML::Document.new
        root = doc.create_element('ListAllMyBucketsResult')
        doc.add_child(root)

        owner = doc.create_element('Owner')
        owner_id = doc.create_element('ID', 'owner_id')
        owner_name = doc.create_element('DisplayName', 'owner_name')
        owner.add_child(owner_id)
        owner.add_child(owner_name)
        root.add_child(owner)

        buckets_container = doc.create_element('Buckets')
        root.add_child(buckets_container)

        buckets.each do |b|
          bucket_container = doc.create_element('Bucket')
          buckets_container.add_child(bucket_container)

          location = doc.create_element('Location', b.location)
          name = doc.create_element('Name', b.name)
          creation_date = doc.create_element('CreationDate', b.creation_time.to_s)
          bucket_container.add_child(location)
          bucket_container.add_child(name)
          bucket_container.add_child(creation_date)
        end

        unless more.empty?
          prefix_node = doc.create_element('Prefix', more[:prefix])
          marker_node = doc.create_element('Marker', more[:marker])
          limit_node = doc.create_element('MaxKeys', more[:limit])
          truncated_node = doc.create_element('IsTruncated', more[:truncated])
          next_marker_node = doc.create_element('NextMarker', more[:next_marker])

          root.add_child(prefix_node)
          root.add_child(marker_node)
          root.add_child(limit_node)
          root.add_child(truncated_node)
          root.add_child(next_marker_node)
        end

        doc.to_xml
      end

      context "List all buckets" do
        # 测试list_bucket正确地发送了HTTP请求
        it "should send correct request" do
          stub_request(:get, @host)

          @oss.list_bucket

          expect(WebMock).to have_requested(:get, @host).
                              with(:body => nil, :query => {})
        end

        # 测试list_bucket正确地解析了list_bucket的返回
        it "should correctly parse response" do
          stub_request(:get, @host).to_return(
            {:body => mock_response(@all_buckets, {})})

          buckets, more = @oss.list_bucket
          bucket_names = buckets.map {|b| b.name}

          all_bucket_names = @all_buckets.map {|b| b.name}
          expect(bucket_names).to match_array(all_bucket_names)

          expect(more).to be_empty
        end
      end

      context "Paging buckets" do
        # 测试list_bucket的请求中包含prefix/marker/maxkeys等信息
        it "should set prefix/max-keys param" do
          prefix = 'rubysdk-bucket-00'
          marker = 'rubysdk-bucket-002'
          limit = 5

          stub_request(:get, @host).with(
            :query => {'prefix' => prefix, 'marker' => marker, 'max-keys' => limit})

          @oss.list_bucket(
            :prefix => prefix, :limit => limit, :marker => marker)

          expect(WebMock).to have_requested(:get, @host).
            with(:body => nil,
                 :query => {'prefix' => prefix,
                            'marker' => marker,
                            'max-keys' => limit})
        end

        # 测试list_bucket正确地解析了HTTP响应，包含more信息
        it "should parse next marker" do
          prefix = 'rubysdk-bucket-00'
          marker = 'rubysdk-bucket-002'
          limit = 5
          next_marker = 'rubysdk-bucket-007'
          more = {:prefix => prefix, :marker => marker, :limit => limit,
                  :next_marker => next_marker, :truncated => true}

          stub_request(:get, @host).with(
            :query => {'prefix' => prefix, 'marker' => marker, 'max-keys' => limit}
          ).to_return(
            {:body => mock_response(@all_buckets[1, 5], more)})

          buckets, more = @oss.list_bucket(
                     :prefix => prefix,
                     :limit => limit,
                     :marker => marker)

          bucket_names = buckets.map {|b| b.name}
          return_bucket_names = @all_buckets[1, 5].map {|b| b.name}
          expect(bucket_names).to match_array(return_bucket_names)

          expect(more).to eq({
            :prefix => prefix,
            :marker => marker,
            :limit => limit,
            :next_marker => next_marker,
            :truncated => true})
        end

      end

    end # Bucket
  end # OSS
end # Aliyun
