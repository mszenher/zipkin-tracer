# Zipkin-Tracer Gem
This document primarily describes the Zipkin tracer ruby gem.  For general information about Zipkin, including installation 
and usage, see the [Zipkin repository](https://github.com/twitter/zipkin).

This gem does two things:

* It provides Rack middleware which plucks Zipkin activity information out of incoming requests and sends it to 
Zipkin.  The middleware also puts Zipkin activity information in `Thread.current` so that it is available to the consuming
application.
* It provides Faraday middleware which puts Zipkin tracing information into outgoing requests, so long as those requests are made by a Faraday instance.

## Usage
Assuming you are using Bundler, update your Gemfile as follows:
```
gem 'zipkin-tracer', :git => 'git@github.com:mszenher/zipkin-tracer.git', :require => 'zipkin-tracer', :tag => 'v0.0.3'
gem 'thin'
```
Of course, you can change the `:tag` option from `'v0.0.3` to any tagged version you choose.  Also, the dependence on the `thin`
gem will hopefully go away soon.

Initialize the middleware as follows (this assumes you are doing the initialization in a Rails `config/initializers` file, e.g. 
`config/initializers/zipkin.rb`):
```
config = Rails.application.config

zipkin_tracer_config = {service_name: 'your service name here', service_port: 9410, sample_rate: 1, scribe_server: '127.0.0.1:9410'}

config.middleware.use ZipkinTracer::RackHandler, zipkin_tracer_config
```

In production, you'll probably want to set your `sample_rate` to something less than 1 (which equal 100% sampling); the 
literature mentions acceptable sampling rates as low as 0.01% for high-traffic servers.  The url and port of your scribe server may vary as well.

To use the Faraday middleware, simply instruct Faraday to use the middleware.  No configuration is required.  You'll probably do something like this:
```
connection = Faraday.new 'http://example.com/api' do |conn|
...
  conn.use ZipkinTracer::FaradayHandler
...
  conn.adapter Faraday.default_adapter
end
```
