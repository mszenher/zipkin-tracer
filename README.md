# Zipkin-Tracer Gem
This document primarily describes the Zipkin tracer ruby gem.  For general information about Zipkin, including installation 
and usage, see the [general README]('../../README.md')

This gem does two things:

* It provides rack-middleware which plucks Zipkin activity information out of incoming requests and sends it to 
Zipkin.  The middleware also puts Zipkin activity information in `Thread.current` so that it is available to the consuming
application.
* It patches `Net::HTTP` very minimally to send Zipkin trace information in all outgoing requests so long as the request is made by `Net::HTTP`.

## Usage
Assuming you are using Bundler, update your Gemfile as follows:
```
gem 'zipkin-tracer', :git => 'git://github.com/mszenher/zipkin-tracer.git', :branch => 'master'
```
Initialize the middleware as follows (this assumes you are doing the initialization in a Rails `config/initializers` file):
```
config = Rails.application.config

require 'zipkin-tracer'
zipkin_tracer = {service_name: 'your service name here', service_port: 9410, sample_rate: 1, scribe_server: "127.0.0.1:9410"}

config.middleware.use ZipkinTracer::RackHandler, zipkin_tracer
```

In production, you'll probably want to set your `sample_rate` to something less than 1 (which equal 100% sampling).  The url of your 
scribe server may vary as well.
