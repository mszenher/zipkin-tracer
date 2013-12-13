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
gem 'zipkin-tracer', '0.2.0', :git => 'git://github.com/mszenher/zipkin.git', :branch => 'master'
```
Note:  you must specify a version above, but the version need not be `0.2.0`; this is just an example.

