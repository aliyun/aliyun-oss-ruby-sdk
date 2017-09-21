# Put it under: RAILS-APP/config/initializers/

require 'aliyun/oss'

##
# Help initialize OSS Client. User can use it easily at any place in
# your rails application.
# @example
#   OSS.client.list_buckets
#   bucket = OSS.client.get_bucket('my-bucket')
#   bucket.list_objects
module OSS
  def self.client
    unless @client
      Aliyun::Common::Logging.set_log_file('./log/oss_sdk.log')

      @client = Aliyun::OSS::Client.new(
        endpoint:
          Rails.application.secrets.aliyun_oss['endpoint'],
        access_key_id:
          Rails.application.secrets.aliyun_oss['access_key_id'],
        access_key_secret:
          Rails.application.secrets.aliyun_oss['access_key_secret']
      )
    end

    @client
  end
end
