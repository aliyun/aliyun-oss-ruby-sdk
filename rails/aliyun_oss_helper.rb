# Put it under: RAILS-APP/app/helpers/

module AliyunOssHelper
  ##
  # Generate a form for upload file to OSS
  # @param [OSS::Bucket] bucket the bucket
  # @param [Hash] opts custom options
  # @option opts [String] :prefix the prefix of the result object
  # @option opts [String] :save_as the object key without prefix of
  #  the result object
  # @option opts [ActiveSupport::Duration] :expiry the expiration time
  #  of this form. Defaults to 60 seconds
  # @option opts [String] :redirect the page after successfully upload
  #  the object
  # @example in controller
  #   @bucket = OSS.client.get_bucket('my-bucket')
  #   @options = {:prefix => '/foo/', :expiry => 60.seconds,
  #               :redirect => 'http://my-domain.com'}
  # @example in views
  #   <%= upload_form(@bucket, @options) do %>
  #   <input type="file" name="file" style="display:inline" />
  #   <button type="submit">Upload</button>
  def upload_form(bucket, opts, &block)
    content = ActiveSupport::SafeBuffer.new

    content.safe_concat(
      form_tag_html(
        html_options_for_form(bucket.bucket_url, multipart: true)))

    key = if opts[:save_as]
            opts[:save_as]
          else
            "${filename}"
          end
    content << hidden_field_tag(:key, "#{opts[:prefix]}#{key}")
    content << hidden_field_tag(:OSSAccessKeyId, bucket.access_key_id)
    expiry = opts[:expiry] || 60.seconds
    policy = {
      'expiration' => (Time.now + expiry).utc.iso8601.sub('Z', '.000Z'),
      'conditions' => [{'bucket' => bucket.name}]
    }
    policy_string = Base64.strict_encode64(policy.to_json)
    content << hidden_field_tag(:policy, policy_string)
    content << hidden_field_tag(:Signature, bucket.sign(policy_string))
    if opts[:redirect]
      content << hidden_field_tag(:success_action_redirect, opts[:redirect])
    end

    content << capture(&block)

    content.safe_concat("</form>")
  end
end
