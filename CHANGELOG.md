## Change Log

### v0.3.7

- Remove monkey patch for Hash

### v0.3.6

- Fix Zlib::Inflate in ruby-1.9.x
- Add function test(tests/) in travis CI
- Add Gem version badge
- Support IP endpoint

### v0.3.5

- Fix the issue that StreamWriter will read more bytes than wanted

### v0.3.4

- Fix handling gzip/deflate response
- Change the default accept-encoding to 'identity'
- Allow setting custom HTTP headers in get_object

### v0.3.3

- Fix object key problem in batch_delete

### v0.3.2

- Allow setting custom HTTP headers in put/append/resumable_upload
- Allow setting object acl in put/append

### v0.3.1

- Fix frozen string issue in OSSClient/STSClient config

### v0.3.0

- Add support for OSS Callback

### v0.2.0

- Add aliyun/sts
- OSS::Client support STS

### v0.1.8

- Fix StreamWriter string encoding problem
- Add ruby version and os version in User-Agent
- Some comments & examples refine

### v0.1.7

- Fix StreamWriter#inspect bug
- Fix wrong in README

### v0.1.6

- Required ruby version >= 1.9.3 due to 1.9.2 has String encoding
  compatibility problems
- Add travis & overalls
- Open source to github.com

### v0.1.5

- Add open_timeout and read_timeout config
- Fix a concurrency bug in resumable_upload/download

### v0.1.4

- Fix object key encoding problem
- Fix Content-Type problem
- Add list_uploads & abort_uploads methods
- Make resumable_upload/download faster by multi-threading
- Enable log rotate

### v0.1.3

- Include request id in exception message

### v0.1.2

- Fix yard doc unresolved link

### v0.1.1

- Add README.md CHANGELOG.md in gem
