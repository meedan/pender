ENV['RAILS_ENV'] ||= 'test'
require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'webmock'
require 'mocha/test_unit'
require 'sample_data'
require 'pender_exceptions'

class Api::V1::TestController < Api::V1::BaseApiController
  before_filter :verify_payload!, only: [:notify]
  skip_before_filter :authenticate_from_token!, only: [:notify]

  def test
    @p = get_params
    render_success
  end

  def notify
    render_success 'success', @payload
  end
end

class ActiveSupport::TestCase
  ActiveRecord::Migration.check_pending!

  include SampleData

  # This will run before any test

  def setup
    Rails.cache.clear if File.exists?(File.join(Rails.root, 'tmp', 'cache'))
    FileUtils.rm_rf File.join(Rails.root, 'public', 'cache', 'test')
    Rails.application.reload_routes!
  end

  # This will run after any test

  def teardown
    WebMock.reset!
    WebMock.allow_net_connect!
    Time.unstub(:now)
    Media.any_instance.unstub(:parse)
    Media.any_instance.unstub(:as_json)
    CONFIG.unstub(:[])
  end

  def authenticate_with_token(api_key = nil)
    unless @request.nil?
      header = CONFIG['authorization_header'] || 'X-Token'
      api_key ||= create_api_key
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
end
