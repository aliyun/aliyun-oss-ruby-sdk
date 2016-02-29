# Aliyun OSS SDK for Ruby

[![Gem Version](https://badge.fury.io/rb/aliyun-sdk.svg)](https://badge.fury.io/rb/aliyun-sdk)
[![Build Status](https://travis-ci.org/aliyun/aliyun-oss-ruby-sdk.svg)](https://travis-ci.org/aliyun/aliyun-oss-ruby-sdk)
[![Coverage Status](https://coveralls.io/repos/aliyun/aliyun-oss-ruby-sdk/badge.svg?branch=master&service=github)](https://coveralls.io/github/aliyun/aliyun-oss-ruby-sdk?branch=master)

-----

Aliyun OSS SDK for Ruby是用于方便访问阿里云OSS（Object Storage Service）
RESTful API的Ruby客户端程序。了解OSS的的更多信息请访问OSS官网：
http://www.aliyun.com/product/oss

## 运行环境

- Ruby版本 >= 1.9.3
- 支持Ruby运行环境的Windows/Linux/OS X

安装Ruby请参考：https://www.ruby-lang.org/zh_cn/downloads/

## 快速开始

### 开通OSS账号

登录官网：http://www.aliyun.com/product/oss ，点击“立即开通”。按照提示
开通OSS服务。开通服务之后请在“管理控制台”中查看您的AccessKeyId和
AccessKeySecret，在使用Aliyun OSS SDK时需要提供您的这两个信息。

### 安装Aliyun OSS SDK for Ruby

    gem install aliyun-sdk

并在你的程序中或者`irb`命令下包含：

    require 'aliyun/oss'

**注意：**

1. SDK依赖的一些gem是本地扩展的形式，因此安装完Ruby之后还需要安装
   ruby-dev以支持编译本地扩展的gem
2. SDK依赖的处理XML的gem(nokogiri)要求环境中包含zlib库

以Ubuntu为例，安装上述依赖的方法：

    sudo apt-get install ruby-dev
    sudo apt-get install zlib1g-dev

### 创建Client

    client = Aliyun::OSS::Client.new(
      :endpoint => 'endpoint',
      :access_key_id => 'access_key_id',
      :access_key_secret => 'access_key_secret')

其中`endpoint`是OSS服务的地址，根据节点区域不同，这个地址可能不一样，例如
杭州节点的地址是：`http://oss-cn-hangzhou.aliyuncs.com`，其他节点的地址见：
[节点列表][region-list]

`access_key_id`和`access_key_secret`是您的服务凭证，在官网的“管理控制
台”上面可以查看。**请妥善保管您的AccessKeySecret，泄露之后可能影响您的
数据安全**

#### 使用用户绑定的域名作为endpoint

OSS支持自定义域名绑定，允许用户将自己的域名指向阿里云OSS的服务地址
（CNAME），这样用户迁移到OSS上时应用内资源的路径可以不用修改。绑定的域
名指向OSS的一个bucket。绑定域名的操作只能在OSS控制台进行。更多关于自定
义域名绑定的内容请到官网了解：[OSS自定义域名绑定][custom-domain]

用户绑定了域名后，使用SDK时指定的endpoint可以使用标准的OSS服务地址，也
可以使用用户绑定的域名：

    client = Aliyun::OSS::Client.new(
      :endpoint => 'http://img.my-domain.com',
      :access_key_id => 'access_key_id',
      :access_key_secret => 'access_key_secret',
      :cname => true)

有以下几点需要注意：

1. 在Client初始化时必须指定:cname为true
2. 自定义域名绑定了OSS的一个bucket，所以用这种方式创建的client不能进行
   list_buckets操作
3. 在{Aliyun::OSS::Client#get_bucket}时仍需要指定bucket名字，并且要与
   域名所绑定的bucket名字相同

#### 使用STS创建Client

OSS支持用户使用STS进行访问，更多有关STS的内容，请参考 [阿里云STS][aliyun-sts]。
在使用STS之前需要先向STS申请一个临时token，
aliyun-sdk中包含了STS的SDK，使用时只需要`require 'aliyun/sts'`即可：

    require 'aliyun/sts'
    sts = Aliyun::STS::Client.new(
      access_key_id: 'access_key_id',
      access_key_secret: 'access_key_secret')

    token = sts.assume_role('role-arn', 'my-app')

    client = Aliyun::OSS::Client.new(
      :endpoint => 'http://oss-cn-hangzhou.aliyuncs.com',
      :access_key_id => token.access_key_id,
      :access_key_secret => token.access_key_secret,
      :sts_token => token.security_token)

注意使用STS时必须指定`:sts_token`参数。用户还可以通过`STS::Client`申请
带Policy的token，细节请参考[API文档][sdk-api]。

### 列出当前所有的Bucket

    buckets = client.list_buckets
    buckets.each{ |b| puts b.name }

`list_buckets`返回的是一个迭代器，用户依次获取每个Bucket的信息。Bucket
对象的结构请查看API文档中的{Aliyun::OSS::Bucket}

### 创建一个Bucket

    bucket = client.create_bucket('my-bucket')

### 列出Bucket中所有的Object

    bucket = client.get_bucket('my-bucket')
    objects = bucket.list_objects
    objects.each{ |o| puts o.key }

`list_objects`返回的是一个迭代器，用户依次获取每个Object的信息。Object
对象的结构请查看API文档中的{Aliyun::OSS::Object}

### 在Bucket中创建一个Object

    bucket.put_object(object_key){ |stream| stream << 'hello world' }

用户也可以通过上传本地文件创建一个Object：

    bucket.put_object(object_key, :file => local_file)

### 从Bucket中下载一个Object

    bucket.get_object(object_key){ |content| puts content }

用户也可以将Object下载到本地文件中：

    bucket.get_object(object_key, :file => local_file)

### 拷贝Object

    bucket.copy_object(from_key, to_key)

### 判断一个Object是否存在

    bucket.object_exists?(object_key)

更多Bucket的操作请参考API文档中的{Aliyun::OSS::Bucket}

## 模拟目录结构

OSS是Object存储服务，本身不支持目录结构，所有的object都是“平”的。但是
用户可以通过设置object的key为"/foo/bar/file"这样的形式来模拟目录结构。
假设现在有以下Objects：

    /foo/x
    /foo/bar/f1
    /foo/bar/dir/file
    /foo/hello/file

列出"/foo/"目录下的所有文件就是以"/foo/"为prefix进行`list_objects`，但
是这样也会把"/foo/bar/"下的所有object也列出来。为此需要用到delimiter参
数，其含义是从prefix往后遇到第一个delimiter时停止，这中间的key作为
Object的common prefix，包含在`list_objects`的结果中。

    objs = bucket.list_objects(:prefix => '/foo/', :delimiter => '/')
    objs.each do |i|
      if i.is_a?(Aliyun::OSS::Object) # a object
        puts "object: #{i.key}"
      else
        puts "common prefix: #{i}"
      end
    end
    # output
    object: /foo/x
    common prefix: /foo/bar/
    common prefix: /foo/hello/

Common prefix让用户不需要遍历所有的object（可能数量巨大）而找出前缀，
在模拟目录结构时非常有用。

## 上传回调

在`put_object`和`resumable_upload`时可以指定一个`Callback`，这样在文件
成功上传到OSS之后，OSS会向用户提供的服务器地址发起一个HTTP POST请求，
以通知用户相应的事件发生了。用户可以在收到这个通知之后进行相应的动作，
例如更新数据库、统计行为等。更多有关上传回调的内容请参考[OSS上传回调][oss-callback]。

下面的例子将演示如何使用上传回调：

    callback = Aliyun::OSS::Callback.new(
      url: 'http://10.101.168.94:1234/callback',
      query: {user: 'put_object'},
      body: 'bucket=${bucket}&object=${object}'
    )

    begin
      bucket.put_object('files/hello', callback: callback)
    rescue Aliyun::OSS::CallbackError => e
      puts "Callback failed: #{e.message}"
    end

**注意**

1. callback的url**不能**包含query string，而应该在`:query`参数中指定
2. 可能出现文件上传成功，但是执行回调失败的情况，此时client会抛出
   `CallbackError`，用户如果要忽略此错误，需要显式接住这个异常。
3. 详细的例子可以参考[callback.rb](examples/aliyun/oss/callback.rb)
4. 接受回调的server可以参考[callback_server.rb](rails/aliyun_oss_callback_server.rb)

## 断点上传/下载

OSS支持大文件的存储，用户如果上传/下载大文件(Object)的时候中断了（网络
闪断、程序崩溃、机器断电等），重新上传/下载是件很费资源的事情。OSS支持
Multipart的功能，可以在上传/下载时将大文件进行分片传输。Aliyun OSS SDK
基于此提供了断点上传/下载的功能。如果发生中断，可以从上次中断的地方继
续进行上传/下载。对于文件大小超过100MB的文件，都建议采用断点上传/下载
的方式进行。

### 断点上传

    bucket.resumable_upload(object_key, local_file, :cpt_file => cpt_file)

其中`:cpt_file`指定保存上传中间状态的checkpoint文件所在的位置，如果用户
没有指定，SDK将为用户在`local_file`所在的目录生成一个
`local_file.cpt`。上传中断后，只需要提供相同的cpt文件，上传将会从
中断的点继续上传。所以典型的上传代码是：

    retry_times = 5
    retry_times.times do
      begin
        bucket.resumable_upload(object_key, local_file)
      rescue => e
        logger.error(e.message)
      end
    end

注意：

1. SDK会将上传的中间状态信息记录在cpt文件中，所以要确保用户对cpt文
   件有写权限
2. cpt文件记录了上传的中间状态信息并自带了校验，用户不能去编辑它，如
   果cpt文件损坏则上传无法继续。整个上传完成后cpt文件会被删除。

### 断点下载

    bucket.resumable_download(object_key, local_file, :cpt_file => cpt_file)

其中`:cpt_file`指定保存下载中间状态的checkpoint文件所在的位置，如果用户
没有指定，SDK将为用户在`local_file`所在的目录生成一个
`local_file.cpt`。下载中断后，只需要提供相同的cpt文件，下载将会从
中断的点继续下载。所以典型的下载代码是：

    retry_times = 5
    retry_times.times do
      begin
        bucket.resumable_download(object_key, local_file)
      rescue => e
        logger.error(e.message)
      end
    end

注意：

1. 在下载过程中，对于下载完成的每个分片，会在`local_file`所在的目录生
   成一个`local_file.part.N`的临时文件。整个下载完成后这些文件会被删除。
   用户不能去编辑或删除part文件，否则下载不能继续。
2. SDK会将下载的中间状态信息记录在cpt文件中，所以要确保用户对cpt文
   件有写权限
3. cpt文件记录了下载的中间状态信息并自带了校验，用户不能去编辑它，如
   果cpt文件损坏则下载无法继续。整个下载完成后cpt文件会被删除。


## 可追加的文件

阿里云OSS中的Object分为两种类型：Normal和Appendable。

- 对于Normal Object，每次上传都是作为一个整体，如果一个Object已存在，
  两次上传相同key的Object将会覆盖原有的Object
- 对于Appendable Object，第一次通过`append_object`创建它，后续的
  `append_object`不会覆盖原有的内容，而是在Object末尾追加内容
- 不能向Normal Object追加内容
- 不能拷贝一个Appendable Object

### 创建一个Appendable Object

    bucket.append_object(object_key, 0){ |stream| stream << "hello world" }

第二个参数是追加的位置，对一个Object第一次追加时，这个参数为0。后续的
追加这个参数要求是追加前Object的长度。

当然，也可以从文件中读取追加的内容：

    bucket.append_object(object_key, 0, :file => local_file)

### 向Object追加内容

    pos = bucket.get_object(object_key).size
    next_pos = bucket.append_object(object_key, pos, :file => local_file)

程序第一次追加时，可以通过{Aliyun::OSS::Bucket#get_object}获取文件的长度，
后续追加时，可以根据{Aliyun::OSS::Bucket#append_object}返回的下次追加长度。

注意：如果并发地`append_object`，`next_pos`并不总是对的。

## Object meta信息

在上传Object时，除了Object内容，OSS还允许用户为Object设置一些"meta信息
"，这些meta信息是一个个的Key-Value对，用于标识Object特有的属性信息。这
些meta信息会跟Object一起存储，并在`get_object`和`get_object`时返
回给用户。

    bucket.put_object(object_key, :file => local_file,
                      :metas => {
                        'key1' => 'value1',
                        'key2' => 'value2'})

    obj = bucket.get_object(object_key, :file => localfile)
    puts obj.metas

关于meta信息有以下几点需要注意：

1. meta信息的key和value都只能是简单的ASCII非换行字符，并且总的大小不能超过8KB。
2. Copy object时默认将拷贝源object的meta信息，如果用户不希望这么做，需要
   显式地将`:meta_directive`设置成{Aliyun::OSS::MetaDirective::REPLACE}

## 权限控制

OSS允许用户对Bucket和Object分别设置访问权限，方便用户控制自己的资源可
以被如何访问。对于Bucket，有三种访问权限：

- public-read-write 允许匿名用户向该Bucket中创建/获取/删除Object
- public-read 允许匿名用户获取该Bucket中的Object
- private 不允许匿名访问，所有的访问都要经过签名

创建Bucket时，默认是private权限。之后用户可以通过`bucket.acl=`来设置
Bucket的权限。

    bucket.acl = Aliyun::OSS::ACL::PUBLIC_READ
    puts bucket.acl # public-read

对于Object，有四种访问权限：

- default 继承所属的Bucket的访问权限，即与所属Bucket的权限值一样
- public-read-write 允许匿名用户读写该Object
- public-read 允许匿名用户读该Object
- private 不允许匿名访问，所有的访问都要经过签名

创建Object时，默认为default权限。之后用户可以通过
`bucket.set_object_acl`来设置Object的权限。

    acl = bucket.get_object_acl(object_key)
    puts acl # default
    bucket.set_object_acl(object_key, Aliyun::OSS::ACL::PUBLIC_READ)
    acl = bucket.get_object_acl(object_key)
    puts acl # public-read

需要注意的是：

1. 如果设置了Object的权限，则访问该Object时进行权限认证时会优先判断
   Object的权限，而Bucket的权限设置会被忽略。
2. 允许匿名访问时（设置了public-read或者public-read-write权限），用户
   可以直接通过浏览器访问，例如：

        http://bucket-name.oss-cn-hangzhou.aliyuncs.com/object.jpg

3. 访问具有public权限的Bucket/Object时，也可以通过创建匿名的Client来进行：

        # 不填access_key_id和access_key_secret，将创建匿名Client，只能访问
        # 具有public权限的Bucket/Object
        client = Client.new(:endpoint => 'oss-cn-hangzhou.aliyuncs.com')
        bucket = client.get_bucket('public-bucket')
        obj = bucket.get_object('public-object', :file => local_file)

## 运行examples

SDK的examples/目录下有一些展示SDK功能的示例程序，用户稍加配置就可以直
接运行。examples需要的权限信息和bucket信息从用户`HOME`目录下的配置文件
`~/.oss.yml`中读取，其中应该包含以下字段（**注意冒号后面需要有一个空格**）：

    endpoint: oss-cn-hangzhou.aliyuncs.com
    cname: false
    access_key_id: <ACCESS KEY ID>
    access_key_secret: <ACCESS KEY SECRET>
    bucket: <BUCKET NAME>

用户需要创建（如果不存在）或者修改其中的内容，然后运行：

    ruby examples/aliyun/oss/bucket.rb

## 运行测试

```bash
bundle exec rake spec

export RUBY_SDK_OSS_ENDPOINT=endpoint
export RUBY_SDK_OSS_ID=AccessKeyId
export RUBY_SDK_OSS_KEY=AccessKeySecret
export RUBY_SDK_OSS_BUCKET=bucket-name

bundle exec rake test
```

## 更多

更多文档请查看：

- 阿里云官网文档：http://help.aliyun.com/product/8314910_oss.html


[region-list]: https://help.aliyun.com/document_detail/oss/user_guide/endpoint_region.html
[custom-domain]: https://help.aliyun.com/document_detail/oss/user_guide/oss_concept/oss_cname.html
[aliyun-sts]: https://help.aliyun.com/document_detail/ram/intro/concepts.html
[sdk-api]: http://www.rubydoc.info/gems/aliyun-sdk/
[oss-callback]: https://help.aliyun.com/document_detail/oss/user_guide/upload_object/upload_callback.html
