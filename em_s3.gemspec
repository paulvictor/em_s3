# -*- encoding: utf-8 -*-
require File.expand_path('../lib/em_s3/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Paul Victor Raj"]
  gem.email         = ["paulvictor@gmail.com"]
  gem.summary       = "Enables evented access to S3 get and put interface"
  gem.description = gem.summary
  gem.homepage      = "http://github.com/paulvictor/em_s3"

  gem.add_dependency('em-http-request', '>=1.0.2')

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "em_s3"
  gem.require_paths = ["lib"]
  gem.version       = EmS3::VERSION
end
