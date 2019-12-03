require 'simplecov'

SimpleCov.start 'rails' do
  nocov_token 'nocov'
  merge_timeout 3600
  command_name "Tests #{rand(100000)}"
  add_filter do |file|
    !file.filename.match(/\/app\/controllers\/concerns\/[^\/]+_doc\.rb$/).nil? ||
    !file.filename.match(/\/app\/workers\/.*screenshot_worker\.rb$/).nil? ||
    !file.filename.match(/\/lib\/pender_redis\.rb$/).nil?
  end
  coverage_dir 'coverage'
end


ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'webmock'
require 'mocha/test_unit'
require 'sample_data'
require 'pender_exceptions'
require 'sidekiq/testing'
require 'minitest/retry'
Minitest::Retry.use!(retry_count: 15)

Minitest::Retry.on_failure do |_klass, _test_name|
  sleep 10
end

class ActiveSupport::TestCase
  ActiveRecord::Migration.check_pending!

  include SampleData

  # This will run before any test

  def setup
    # For debugging only: print the test name before it runs
    # puts "#{self.class.name}::#{self.method_name}"
    Sidekiq::Testing.inline!
    Rails.application.reload_routes!
    Media.any_instance.stubs(:archive_to_archive_is).returns(nil)
    Media.any_instance.stubs(:archive_to_archive_org).returns(nil)
    Media.any_instance.stubs(:archive_to_perma_cc).returns(nil)
    Media.any_instance.unstub(:parse)
    OpenURI.unstub(:open_uri)
    Twitter::REST::Client.any_instance.unstub(:user)
    Twitter::REST::Client.any_instance.unstub(:status)
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_canonical_url)
    Media.any_instance.unstub(:try_https)
    Airbrake.unstub(:configured?)
    Airbrake.unstub(:notify)
    Media.any_instance.unstub(:url)
    Media.any_instance.unstub(:original_url)
    Media.any_instance.unstub(:data_from_page_item)
    Media.any_instance.unstub(:oembed_get_data_from_url)
    Media.any_instance.unstub(:doc)
    Media::ARCHIVERS['archive_is'][:enabled] = true
    Media::ARCHIVERS['perma_cc'][:enabled] = true
    clear_bucket(create: true)
  end

  # This will run after any test

  def teardown
    WebMock.reset!
    WebMock.allow_net_connect!
    Time.unstub(:now)
    Media.any_instance.unstub(:parse)
    Media.any_instance.unstub(:as_json)
    Media.any_instance.unstub(:archive_to_archive_is)
    Media.any_instance.unstub(:archive_to_archive_org)
    Media.any_instance.unstub(:archive_to_perma_cc)
    Media::ARCHIVERS['archive_is'][:enabled] = false
    Media::ARCHIVERS['perma_cc'][:enabled] = false
    CONFIG.unstub(:[])
    clear_bucket
  end

  def clear_bucket(options = {})
    resource = Aws::S3::Resource.new
    bucket = resource.bucket(Pender::Store.bucket_name)
    if bucket.exists?
      bucket.objects.each { |obj| obj.delete }
    else
      bucket.create if options.dig(:create)
    end
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
