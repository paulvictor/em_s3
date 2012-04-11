EM.run{
  s3a = S3Agent.new
  s3a.set_keys('public_key', 'private_key')
  bucket = "bucket"
  object = "obj"
  value = "value"
  prefix = "prefix"
  s3a.request_service(:get, bucket, object){|resp, code|
    if code == 200
      new_value = prefix + resp
    elsif code == 404
      new_value = prefix
    else
      s3a.revoke_service(bucket, object)
      EM.stop
    end
    s3a.request_service(:put, bucket, object, new_value){|resp, code|
      puts "AWS gave a #{code}"
      EM.stop
    }
  }
}
