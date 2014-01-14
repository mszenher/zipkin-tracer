# -*- encoding: utf-8 -*-
# Copyright 2012 Twitter Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'zipkin-tracer/version'

Gem::Specification.new do |s|
  s.name                      = "zipkin-tracer"
  s.version                   = ZipkinTracer::VERSION
  s.authors                   = ["Franklin Hu", "Matthew Szenher", "Aimee Barciauskas"]
  s.email                     = ["franklin@twitter.com", "mszenher@mdsol.com", "abarciauskas@mdsol.com"]
  s.homepage                  = "https://github.com/twitter/zipkin"
  s.summary                   = "Ruby tracing via Zipkin"
  s.description               = "Adds tracing instrumentation for ruby applications"

  s.required_rubygems_version = ">= 1.3.5"

  s.files                     = Dir.glob("{bin,lib}/**/*")
  s.require_path              = 'lib'

  s.add_dependency 'finagle-thrift'
  s.add_dependency 'scribe'
  
  s.add_development_dependency 'rspec', '2.14.1'
  s.add_development_dependency 'rspec-mocks', '2.14.1'
  s.add_development_dependency 'debugger', '~> 1.6.0'
  s.add_development_dependency 'simplecov', '0.8.2'
  s.add_development_dependency 'rack', '1.5.2'
  s.add_development_dependency 'thin', '1.6.1'
  s.add_development_dependency 'faraday', '0.8.8'
  s.add_development_dependency 'addressable'
end
