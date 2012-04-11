EM.run{
  s3i = S3Interface.new('your_aws_key', 'your_aws_secret')
  s3i.callback{|resp, code|
    puts "AWS replied with #{resp} and #{code}"
    EM.stop
  }
  s3i.put_object('my_bucket', 'foo', 'bar')
}

EM.run{
  s3i = S3Interface.new('your_aws_key', 'your_aws_secret')
  s3i.callback{|resp, code|
    puts "AWS replied with #{resp} and #{code}"
    EM.stop
  }
  s3i.get_object('my_bucket', 'foo')
}
