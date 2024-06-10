source 'https://rubygems.org'
gem 'rails', '~> 6.1.7'
gem 'pg', '1.1'
group :development, :test do
  gem 'byebug'
  gem 'gem-licenses'
  gem 'rspec-rails'
  # workaround for https://github.com/rswag/rswag/issues/317, remove GIT repository after https://github.com/rswag/rswag/pull/319 is merged
  gem 'rswag-specs', git: 'https://github.com/jetpackworkflow/rswag.git', branch: 'allow_oas3_param_schema_array'
  gem 'get_process_mem'
  gem 'derailed'
  gem "spring"
end
gem 'memory_profiler'
group :development do
  gem 'web-console', '~> 3.5.1'
  gem 'awesome_print', require: false
end
group :test do
  gem 'parallel_tests'
  gem "mocha", '~> 1.14.0', require: false
  gem 'simplecov', '0.13.0', require: false
  gem 'simplecov-console', require: false
  gem 'codeclimate-test-reporter', '1.0.8', group: :test, require: nil
  gem 'rails-controller-testing'
  gem 'minitest', '5.10.1'
  gem 'minitest-retry'
  gem 'webmock'
end
gem 'logstash-logger'
gem 'railroady'

gem 'sentry-ruby'
gem 'sentry-rails'
gem 'sentry-sidekiq'

gem 'responders'
gem 'yt', '~> 0.25.5'
gem 'rswag-api'
gem 'rswag-ui'
gem 'sass-rails'
gem 'open_uri_redirections', require: false
gem 'postrank-uri', git: 'https://github.com/postrank-labs/postrank-uri.git', ref: '485ac46', require: false # Ruby 3.0 support, as of 2/6/23 no gem relaease
gem 'retryable'
gem 'puma', '5.6.8'
gem 'rack-cors', '>= 2.0.2', :require => 'rack/cors'
gem 'rails-perftest'
gem 'sidekiq', '< 8'
gem 'redis', '4.3.1'
gem 'nokogiri', '1.16.5', require: false
gem 'htmlentities', require: false
gem 'rack-protection', '2.0.1'
gem 'loofah', '2.19.1', require: false
gem 'rails-html-sanitizer', '1.4.4'
gem 'sprockets', '3.7.2'
gem 'rack', '>= 1.6.11', require: false
gem 'aws-sdk-s3', require: false
gem 'lograge'
gem 'request_store'
gem 'opentelemetry-sdk'
gem 'opentelemetry-exporter-otlp'
gem 'opentelemetry-instrumentation-action_pack'
gem 'opentelemetry-instrumentation-action_view'
gem 'opentelemetry-instrumentation-active_job'
gem 'opentelemetry-instrumentation-active_record'
gem 'opentelemetry-instrumentation-active_support'
gem 'opentelemetry-instrumentation-aws_sdk'
gem 'opentelemetry-instrumentation-concurrent_ruby'
gem 'opentelemetry-instrumentation-http'
gem 'opentelemetry-instrumentation-net_http'
gem 'opentelemetry-instrumentation-rack'
gem 'opentelemetry-instrumentation-rails'
gem 'opentelemetry-instrumentation-rake'
gem 'opentelemetry-instrumentation-sidekiq'
gem 'addressable', '2.8.1'
# Adding this removes some deprecation warnings, caused by double-loading of the net-protocol library
# (see https://github.com/ruby/net-imap/issues/16). We *might* be able to remove this after upgrading to Ruby 3
gem 'net-http'
gem 'prometheus-client'
