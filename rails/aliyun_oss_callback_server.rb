# coding: utf-8

require 'sinatra'
require 'base64'
require 'open-uri'
require 'cgi'
require 'openssl'
require 'json'

# 接受OSS上传回调的server示例，利用RSA公钥验证请求来自OSS，而非其
# 他恶意请求。具体签名/验证过程请参考：
# https://help.aliyun.com/document_detail/oss/api-reference/object/Callback.html

def get_header(name)
  key = "http_#{name.gsub('-', '_')}".upcase
  request.env[key]
end

PUB_KEY_URL_PREFIX = 'http://gosspublic.alicdn.com/'
PUB_KEY_URL_PREFIX_S = 'https://gosspublic.alicdn.com/'

# 1. Public key is cached so that we don't need fetching it for every
#    request
# 2. Ensure pub_key_url is an authentic URL by asserting it starts
#    with the offical domain
def get_public_key(pub_key_url, reload = false)
  unless pub_key_url.start_with?(PUB_KEY_URL_PREFIX) ||
         pub_key_url.start_with?(PUB_KEY_URL_PREFIX_S)
    fail "Invalid public key URL: #{pub_key_url}"
  end

  if reload || @pub_key.nil?
    @pub_key = open(pub_key_url) { |f| f.read }
  end

  @pub_key
end

post '/*' do
  pub_key_url = Base64.decode64(get_header('x-oss-pub-key-url'))
  pub_key = get_public_key(pub_key_url)
  rsa = OpenSSL::PKey::RSA.new(pub_key)

  authorization = Base64.decode64(get_header('authorization'))
  req_body = request.body.read

  auth_str = if request.query_string.empty?
    CGI.unescape(request.path) + "\n" + req_body
  else
    CGI.unescape(request.path) + '?' + request.query_string + "\n" + req_body
  end

  valid = rsa.public_key.verify(OpenSSL::Digest::MD5.new, authorization, auth_str)

  if valid
    if request.content_type == 'application/www-form-urlencoded'
      body(URI.decode_www_form(req_body).to_h.to_json)
    else
      body(req_body)
    end
  else
    halt 400, "Authorization failed!"
  end
end
