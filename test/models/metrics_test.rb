require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class MetricsIntegrationTest < ActiveSupport::TestCase
  class AllTestFacebookAppsRateLimited < StandardError; end

  test "should get metrics from Facebook" do
    begin
      fb_config = PenderConfig.get('facebook_test_app') || PenderConfig.get('facebook_app')
      PenderConfig.current = nil
      key = create_api_key application_settings: { config: { facebook_app: fb_config }}

      url = 'https://www.google.com/'

      # Make sure we don't send 10 requests to Facebook at once and get rate limited,
      # since Sidekiq otherwise would perform the ten days of updates at once
      Sidekiq::Worker.clear_all
      Sidekiq::Testing.fake! do
        m = create_media url: url, key: key
        m.as_json

        # Perform once for each Facebook app we have in the configuration -
        # in case we get rate limited on the first app id but not second
        allowed_attempts = fb_config.split(";").count
        attempts = 0
        while attempts < allowed_attempts
          begin
            metrics = MetricsWorker.perform_one
            if metrics.blank?
              attempts += 1
              next
            else
              break
            end
          rescue Pender::RetryLater => e
            attempts += 1
            next
          end
        end
        raise AllTestFacebookAppsRateLimited if attempts == allowed_attempts

        id = Media.get_id(m.url)
        data = Pender::Store.current.read(id, :json)

        assert data['metrics']['facebook']['share_count'] > 0
      end
    rescue AllTestFacebookAppsRateLimited => e
      skip "All Facebook apps are being rate limited, skipping..."
    end
  end
end

class MetricsUnitTest < ActiveSupport::TestCase
  def stub_facebook_oauth_request
    WebMock.stub_request(:get, /graph.facebook.com\/oauth\/access_token\?client_id=#{facebook_app_id}/)
      .to_return(status: 200, body: {access_token: 'fake-access-token'}.to_json)
  end

  def stub_facebook_metrics_request
    WebMock.stub_request(:get, /graph.facebook.com\/\S*access_token=fake-access-token/).
      to_return(status: 200, body: {engagement: { shares: '123' }}.to_json)
  end

  def facebook_app_id
    '1111'
  end

  def key
    @key ||= create_api_key application_settings: { config: { facebook_app: "#{facebook_app_id}:2222" }}
  end

  def setup
    isolated_setup
    Semaphore.new(facebook_app_id).unlock
  end

  def teardown
    isolated_teardown
    Semaphore.new(facebook_app_id).unlock
  end

  test 'should queue ten days of metrics updates, including a near-term background job to request initial from facebook' do
    stub_facebook_oauth_request
    stub_facebook_metrics_request

    current_time = Time.now

    assert_difference 'MetricsWorker.jobs.size', 10 do
      Metrics.schedule_fetching_metrics_from_facebook({}, 'https://example.com/trending-article', key.id)
    end

    first_job = MetricsWorker.jobs.first
    assert Time.at(first_job['at']) > current_time
    assert Time.at(first_job['at']) < current_time + 10.minutes
    assert_nil first_job['enqueued_at']

    MetricsWorker.perform_one

    assert MetricsWorker.jobs.count, 1
    second_job = MetricsWorker.jobs.first
    assert Time.at(second_job['at']) > current_time + 12.hours
    assert Time.at(second_job['at']) < current_time + 36.hours
    assert_nil second_job['enqueued_at']
  end

  test 'should retry the scheduled background job on failure' do
    stub_facebook_oauth_request
    stub_facebook_metrics_request

    Metrics.stubs(:verify_facebook_metrics_response).raises(Pender::RetryLater)
    Metrics.schedule_fetching_metrics_from_facebook({}, 'https://example.com/trending-article', key.id)

    assert_raises Pender::RetryLater do
      MetricsWorker.perform_one
    end
  end

  test "should get metrics from Facebook when URL has non-ascii" do
    stub_facebook_oauth_request
    stub_facebook_metrics_request

    metrics = Metrics.get_metrics_from_facebook("http://www.facebook.com/people/\u091C\u0941\u0928\u0948\u0926-\u0905\u0939\u092E\u0926/100014835514496", key.id)
    assert_equal({"shares"=>"123"}, metrics)
  end

  test "should tally Facebook metrics from Crowdtangle when it's a Facebook item" do
    crowdtangle_data = {"result"=>{"posts"=>[{"platformId"=>'post-1234',"account"=>{"id"=>33862, "name"=>"Account name", "handle"=>"accoutn"},"statistics"=>{"actual"=>{"likeCount"=>30813, "shareCount"=>1640, "commentCount"=>457, "loveCount"=>5131, "wowCount"=>74, "hahaCount"=>543, "sadCount"=>2, "angryCount"=>1, "thankfulCount"=>0, "careCount"=>136}}}]}}
    mock_crowdtangle_request = MiniTest::Mock.new
    mock_crowdtangle_request.expect :call, crowdtangle_data, ['facebook', 'uuid-1234']

    mock_notify_webhook = MiniTest::Mock.new
    mock_notify_webhook.expect :call, :return_value, [
      'metrics',
      'http://example.com/facebook-trending-article',
      {
        'metrics' => {
          'facebook' => {
            comment_count: 457,
            reaction_count: 36700,
            share_count: 1640,
            comment_plugin_count: 0,
          }
        }
      },
      Hash
    ]

    Media.stub(:crowdtangle_request, mock_crowdtangle_request) do
      Media.stub(:notify_webhook, mock_notify_webhook) do
        Metrics.schedule_fetching_metrics_from_facebook({ 'uuid' => 'uuid-1234', 'provider' => 'facebook', 'type' => 'item' }, 'http://example.com/facebook-trending-article', key)
        MetricsWorker.perform_one
      end
    end
    mock_crowdtangle_request.verify
    mock_notify_webhook.verify
  end

  test "should notify webhook and update cache with empty metrics data upon error" do
    WebMock.stub_request(:get, /graph.facebook.com\/oauth\/access_token/).to_raise(Net::ReadTimeout.new('Exception from WebMock'))

    url = 'https://example.com/trending-article'
    empty_metrics_data = { 'metrics' => { 'facebook' => {} } }

    mocked_cache_method = MiniTest::Mock.new
    mocked_cache_method.expect :call, :return_value, [url, empty_metrics_data]

    mocked_webhook_method = MiniTest::Mock.new
    mocked_webhook_method.expect :call, :return_value, ['metrics', url, empty_metrics_data, Hash]

    Media.stub(:update_cache, mocked_cache_method) do
      Media.stub(:notify_webhook, mocked_webhook_method) do
        Metrics.get_metrics_from_facebook(url, key.id)
      end
    end
    mocked_cache_method.verify
    mocked_webhook_method.verify
  end

  test "should still update cache if notifying webhook causes error" do
    stub_facebook_oauth_request
    stub_facebook_metrics_request
    Media.stubs(:notify_webhook).raises(StandardError.new("fake error for test"))

    url = 'https://example.com/trending-article'
    id = Media.get_id(url)
    Pender::Store.current.write(id, :json, {some: 'value'})

    data = Pender::Store.current.read(id, :json)
    assert_not data['metrics'].present?

    assert_raises do
      Metrics.get_metrics_from_facebook(url, key.id)
    end

    data = Pender::Store.current.read(id, :json)
    assert data['metrics'].present?
  end

  test "should add error to tracing span and raise retry error when fb metrics returns a retryable error" do
    stub_facebook_oauth_request
    WebMock.stub_request(:get, /graph.facebook.com\/\S*access_token=fake-access-token/).to_return(status: 400, body: "{\"error\":{\"message\":\"Try again soon.\",\"code\":\"101\"}}")

    mocked_tracer = MiniTest::Mock.new
    mocked_tracer.expect :call, :return_value do |message, args|
      message.match(/Facebook metrics error/) &&
        args.keys.count == 5 &&
        args[:attributes]['app.api_key'] == key.id &&
        args[:attributes]['facebook.metrics.error.code'] == "101"
        args[:attributes]['facebook.metrics.error.message'] == 'Try again soon.' &&
        args[:attributes]['facebook.metrics.url'] == 'http://example.com/trending-article' &&
        args[:attributes]['facebook.metrics.retryable']
    end

    assert_raises Pender::RetryLater do
      TracingService.stub(:set_error_status, mocked_tracer) do
        Metrics.get_metrics_from_facebook('http://example.com/trending-article', key.id)
      end
    end
    mocked_tracer.verify
  end

  test "should lock facebook_app when rate limiting detected, and queue for retry" do
    stub_facebook_oauth_request
    WebMock.stub_request(:get, /graph.facebook.com\/\S*access_token=fake-access-token/).to_return(status: 400, body: "{\"error\":{\"message\":\"Application request limit reached.\",\"code\":\"4\"}}")

    locker = Semaphore.new(facebook_app_id)
    assert_raises Pender::RetryLater do
      assert_equal locker.locked?, false
      Metrics.get_metrics_from_facebook('http://example.com/trending-article', key.id)
      assert_equal locker.locked?, true
    end
  end

  test "should use second facebook_app when fails to get fb metrics and api limit reached" do
    # Stub two responses: first failing, second succeeding
    WebMock.stub_request(:get, /graph.facebook.com\/oauth\/access_token\?client_id=1111&client_secret=2222/).
      to_return(status: 200, body: {access_token: 'fake-access-token-1 '}.to_json)
    WebMock.stub_request(:get, /graph.facebook.com\/\S*access_token=fake-access-token-1/).
      to_return(status: 400, body: "{\"error\":{\"message\":\"Application request limit reached.\",\"code\":\"4\"}}")

    WebMock.stub_request(:get, /graph.facebook.com\/oauth\/access_token\?client_id=3333&client_secret=4444/).
      to_return(status: 200, body: {access_token: 'fake-access-token-2'}.to_json)
    WebMock.stub_request(:get, /graph.facebook.com\/\S*access_token=fake-access-token-2/).
      to_return(status: 200, body: {engagement: { shares: '123' } }.to_json)

    api_key = create_api_key application_settings: { config: { facebook_app: "1111:2222;3333:4444" }}
    app_1_locker = Semaphore.new('1111')
    app_2_locker = Semaphore.new('3333')

    assert_raises Pender::RetryLater do
      assert_equal false, app_1_locker.locked?
      Metrics.get_metrics_from_facebook('http://example.com/trending-article', api_key.id)
      # Unlocked as part of normal test teardown
      assert_equal true, app_1_locker.locked?
    end

    assert_equal false, app_2_locker.locked?
    metrics = Metrics.get_metrics_from_facebook('http://example.com/trending-article', api_key.id)
    # Unlock before we exit function with possible failure, since this
    # locker isn't unlocked as part of standard test teardown
    app_2_locked_status = app_2_locker.locked?
    app_2_locker.unlock
    assert_equal false, app_2_locked_status
    assert_equal({"shares"=>"123"}, metrics)
  end

  test "should use api key config to get metrics and storage config if present" do
    stub_facebook_oauth_request
    stub_facebook_metrics_request
    WebMock.stub_request(:any, /example.com\/storage-endpoint/).to_return(status: 200, body: {}.to_json)

    ApiKey.current = PenderConfig.current = Pender::Store.current = nil
    api_key = create_api_key application_settings: {
      config: {
        facebook_app: '1111:2222',
        storage_endpoint: 'https://example.com/storage-endpoint',
        storage_access_key: 'storage-access-key',
        storage_secret_key: 'storage-secret-key',
        storage_bucket: 'my-bucket',
        storage_bucket_region: 'storage-bucket-region',
        storage_video_bucket: 'video-bucket',
        storage_video_asset_path: 'http://video.path',
        storage_medias_asset_path: 'http://medias.path'
      }
    }

    Metrics.get_metrics_from_facebook('http://example.com/trending-article', api_key.id)

    assert_equal api_key, ApiKey.current
    assert_equal api_key.settings[:config][:facebook_app], PenderConfig.current(:facebook_app)
    %w(endpoint access_key secret_key bucket bucket_region video_bucket video_asset_path medias_asset_path).each do |key|
      assert_equal api_key.settings[:config]["storage_#{key}"], PenderConfig.current("storage_#{key}"), "Expected #{key}"
      assert_equal api_key.settings[:config]["storage_#{key}"], Pender::Store.current.instance_variable_get(:@storage)[key]
    end
  end
end
