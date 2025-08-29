require 'simplecov'

# Clean cache directory before tests start
require 'fileutils'
CACHE_PATH = "/tmp/cache#{ENV['TEST_ENV_NUMBER']}"
FileUtils.rm_rf(CACHE_PATH)

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'webmock'
require 'sample_data'
require 'pender/exception'
require 'pender/store'
require 'sidekiq/testing'
require 'minitest/retry'
require 'minitest/mock'
require 'mocha/minitest'

Minitest::Retry.use!(retry_count: ENV['TEST_RETRY_COUNT'].to_i || 0)

Minitest::Retry.on_failure do |_klass, _test_name|
  sleep 10
end

class ActiveSupport::TestCase
  ActiveRecord::Migration.check_all_pending!

  include SampleData

  # Shared setup/teardown for tests as we make
  # the unit tests isolated
  def isolated_setup
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.fake!
    ApiKey.current = PenderConfig.current = Pender::Store.current = nil
  end

  def isolated_teardown
    Sidekiq::Worker.clear_all
    Sidekiq::Testing.inline! # reset, to match current test_helper teardown
    WebMock.reset!
    WebMock.allow_net_connect!
    WebMock.disable!
  end

  # This will run before any test

  def setup
    # For debugging only: print the test name before it runs
    # puts "#{self.class.name}::#{self.method_name}"
    Sidekiq::Testing.inline!
    Rails.application.reload_routes!
    Media.any_instance.stubs(:archive_to_archive_org).returns(nil)
    Media.any_instance.stubs(:archive_to_perma_cc).returns(nil)
    Media::ARCHIVERS['perma_cc'][:enabled] = true
    Media::ARCHIVERS['archive_org'][:enabled] = true
    ApiKey.current = Pender::Store.current = PenderConfig.current = nil
    clear_bucket
  end

  # This will run after any test

  def teardown
    WebMock.reset!
    WebMock.allow_net_connect!
    Media::ARCHIVERS['perma_cc'][:enabled] = false
    Media::ARCHIVERS['archive_org'][:enabled] = false
    clear_bucket
  end

  def clear_bucket
    @pender_store = Pender::Store.current
    @pender_store.destroy_buckets
    ApiKey.current = Pender::Store.current = PenderConfig.current = nil
  end

  def authenticate_with_token(api_key = nil)
    unless @request.nil?
      header = PenderConfig.get('authorization_header', 'X-Token')
      api_key ||= create_api_key
      ApiKey.current = api_key
      @request.headers.merge!({ header => api_key.access_token })
    end
  end

  def stub_configs(configs)
    CONFIG.each do |k, v|
      CONFIG.stubs(:[]).with(k).returns(v) unless configs.keys.map(&:to_s).include?(k.to_s)
    end
    configs.each do |k, v|
      CONFIG.stubs(:[]).with(k.to_s).returns(v)
    end
  end

  def with_time(operation = '')
    return if @provider.blank? and @type.blank?
    output = File.join(Rails.root, 'tmp', 'performance.csv')
    results = File.open(output, 'a+')
    start = Time.now
    yield if block_given?
    duration = (Time.now - start) * 1000.0
    data = ["Time to #{operation} a #{@provider} #{@type}", duration.to_s.gsub('.', ',')]
    results.puts(data.join(';'))
    results.close
  end

  def response_fixture_from_file(filename, parse_as: nil)
    fixture_body = ''
    File.open("test/data/#{filename}") { |f| fixture_body = f.read }

    case parse_as
    when :html
      Nokogiri::HTML(fixture_body)
    when :json
      JSON.parse(fixture_body)
    else
      fixture_body
    end
  end
end
