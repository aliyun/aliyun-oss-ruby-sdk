# Aliyun OSS SDK for Ruby

![Build Status](http://cise.alibaba-inc.com/task/119062/build/10/status.svg)

-----

Aliyun::OSS是用于方便访问阿里云OSS（Object Storage Service）RESTful
API的Ruby客户端程序。了解OSS的的更多信息请访问OSS官网：
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

注：**阿里云OSS提供了1GB的免费存储空间，用户可以免费体验OSS服务**

### 安装Aliyun OSS SDK for Ruby

    gem install aliyun-sdk

并在你的程序中包含：

    require 'aliyun/oss'

### 创建Client

#### 创建通用的Client

    client = Aliyun::OSS::Client.new(endpoint, access_key_id, access_key_secret)

其中`endpoint`是OSS服务的地址，根据节点区域不同，这个地址可能不一样，例如
杭州节点的地址是：`oss-cn-hangzhou.oss.aliyuncs.com`，其他节点的地址见：
[节点列表][1]

`access_key_id`和`access_key_secret`是您的服务凭证，在官网的“管理控制
台”上面可以查看。**请妥善保管您的AccessKeySecret，泄露之后可能影响您的
数据安全**

#### 创建指定Bucket的Client

大部分情况下您的操作都是针对一个Bucket进行，这时你可以直接创建一个指定
Bucket的Client：

    bucket = Aliyun::OSS::Client.connect_to_bucket(bucket_name, endpoint, access_key_id, access_key_secret)

也可以先创建`Client`再通过`get_bucket`来连接到指定的Bucket：

    client = Aliyun::OSS::Client.connect_to_bucket(endpoint, access_key_id, access_key_secret)
    bucket = client.get_bucket(bucket_name)

### 列出当前所有的Bucket

    buckets = client.list_buckets
    buckets.each{ |b| puts b.name }

`list_buckets`返回的是一个迭代器，用户依次获取每个Bucket的信息。Bucket
对象的结构请查看API文档中的{Aliyun::OSS::Bucket}

### 创建一个Bucket

    bucket = client.get_bucket('my-bucket')
    bucket.create!

### 列出Bucket中所有的Object

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

### 判断一个Object是否存在

    bucket.object_exists?(object_key)

更多Bucket的操作请参考API文档中的{Aliyun::OSS::Bucket}

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

    pos = bucket.get_object_meta(object_key).size
    next_pos = bucket.append_object(object_key, pos, :file => local_file)

程序第一次追加时，可以通过{Aliyun::OSS::Bucket#get_object_meta}获取文件的长度，
后续追加时，可以根据{Aliyun::OSS::Bucket#append_object}返回的下次追加长度。

注意：如果并发地`append_object`，`next_pos`并不总是对的。

## 更多

更多文档请查看：

- examples目录，里面包含了更多的代码样例
- 阿里云官网文档：https://docs.aliyun.com/?spm=5176.383663.13.7.zbyclQ#/pub/oss
- SDK API文档：http://10.101.168.94/d/aliyun-oss-sdk-doc/


[1]: https://docs.aliyun.com/?spm=5176.383663.13.7.zbyclQ#/pub/oss/product-documentation/domain-region

