class S3Interface
  # Do not use the interfaces' errback to define custom events.
  # Errbacks are used internally to retry.
  include EM::Deferrable
  # Credits to http://forrst.com/posts/Basic_Amazon_S3_Upload_via_PUT_Ruby_Class-4t6
  # Refer to the following for S3 documentation
  # http://docs.amazonwebservices.com/AmazonS3/latest/dev/RESTAuthentication.html#RESTAuthenticationConstructingCanonicalizedAmzHeaders
  # http://docs.amazonwebservices.com/AmazonS3/latest/API/RESTObjectPUT.html
  # http://docs.amazonwebservices.com/AmazonS3/latest/API/RESTObjectGET.html

  attr_accessor :public_key, :private_key

  def initialize(public_key, private_key, options = {})
    @public_key = public_key
    @private_key = private_key
    @options = options.merge({:retry_count => 3})
    @num_tries = 0
    errback{|resp, status|
      if (@num_tries += 1) < retry_count
        retry_request
      else
        succeed resp, status
      end
    }
  end

  # Puts any of the objects into S3 buckets
  # @param [String] bucket
  #   The name of the bucket
  # @param [String] object
  #   The name of the object's key
  # @param [String] value
  #   The object's value
  # @param [String] content_type
  #   The value's MIME type
  # @return [self]
  def put_object(bucket, object, value, content_type = 'binary/octet-stream')
    date = generate_date
    sign_string = generate_signed_string('PUT', 'private', bucket, object, content_type)
    signature = generate_signature(sign_string)
    auth = generate_auth(signature)
    headers = generate_put_headers(date, auth, 'private', content_type, value.size)
    path = "/" << object

    @req_options = {:method => :put, :head => headers, :path => path, :body => value}
    @bucket = bucket
    try_request
    self
  end

  # Gets any of the objects from S3 buckets
  # @param [String] bucket
  #   The name of the bucket
  # @param [String] object
  #   The name of the object's key
  # @return [self]
  def get_object(bucket, object)
    date = generate_date
    sign_string = generate_signed_string('GET', nil, bucket, object, 'text/plain')
    signature = generate_signature(sign_string)
    auth = generate_auth(signature)
    headers = generate_get_headers(date, auth, 'text/plain')
    path = "/" << object

    @req_options = {:method => :get, :head => headers, :path => path}
    @bucket = bucket
    try_request
    self
  end

  private

  # Perhaps an inappropriate method name, sonce we call it even the first time
  def retry_request
    # Explore persistent connections from within AWS
    s3_conn = EM::HttpRequest.new("http://#{@bucket}.s3.amazonaws.com")
    req_method = @req_options[:method]
    s3_req = s3_conn.send(req_method, @req_options)
    s3_req.callback{|cli|
      if cli.response_header.http_status < 500
        self.succeed cli.response, cli.response_header.http_status
      else # Some S3 issue
        self.fail cli.response, cli.response_header.http_status
      end
    }
    s3_req.errback{|cli|
      self.fail nil, nil
    }
  end

  alias :try_request :retry_request

  def generate_date
    Time.now.httpdate
  end

  def generate_signed_string(request_type, access, bucket, object, content_type = 'binary/octet-stream')
    signed_string = ""
    signed_string << request_type << "\n\n"
    if content_type == nil
      signed_string << "\n"
    else
      signed_string << content_type << "\n"
    end
    signed_string << generate_date << "\n"
    signed_string << "x-amz-acl:" << access << "\n" if access
    signed_string << "/" << bucket << "/" << object
  end

  def generate_signature(signed_string)
    Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest::Digest.new('sha1'), @private_key, signed_string)).gsub("\n", "")
  end

  def generate_auth(signature)
    authString = "AWS"
    authString << " "
    authString << @public_key
    authString << ":"
    authString << signature
    authString
  end

  def generate_put_headers(date_string, auth_string, access, content_type = nil, content_length = 0)
    { 'Date' => date_string, 'Content-Type' => content_type, 'Content-Length' => content_length.to_s, 'Authorization' => auth_string, 'Expect' => "100-continue", 'x-amz-acl' => access }
  end

  def generate_get_headers(date_string, auth_string, content_type = 'text/plain')
    { 'Date' => date_string, 'Authorization' => auth_string, 'Content-Type' => content_type }
  end

  def retry_count
    @options[:retry_count]
  end
end
