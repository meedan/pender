require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class MetricsTest < ActiveSupport::TestCase
  test 'should queue a near-term background job to reqeust initial metrics from facebook' do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    WebMock.stub_request(:get, /example.com/).to_return(status: 200, body: '')
    current_time = Time.now
    
    Sidekiq::Testing.fake! do
      m = create_media url: 'http://example.com'
      assert_difference 'MetricsWorker.jobs.size', 1 do
        m.get_metrics
      end
      scheduled_job = MetricsWorker.jobs.first
      assert Time.at(scheduled_job['at']) > current_time
      assert Time.at(scheduled_job['at']) < current_time + 1.minute
      assert_nil scheduled_job['enqueued_at']
    end
  end

  test 'should queue follow-up background jobs to request metrics on following days' do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    WebMock.stub_request(:get, /example.com/).to_return(status: 200, body: '')
    current_time = Time.now
    
    Sidekiq::Testing.fake! do
      m = create_media url: 'http://example.com'
      m.get_metrics
      MetricsWorker.perform_one

      # Perform one removes the first, immediately enqueued background job
      scheduled_job = MetricsWorker.jobs.first
      assert Time.at(scheduled_job['at']) > current_time + 12.hours
      assert Time.at(scheduled_job['at']) < current_time + 36.hours
      assert_nil scheduled_job['enqueued_at']
    end
  end

  test "should get metrics from Facebook" do
    fb_config = PenderConfig.get('facebook_test_app') || PenderConfig.get('facebook_app')
    PenderConfig.current = nil
    key = create_api_key application_settings: { config: { facebook_app: fb_config }}

    url = 'https://www.google.com/'
    m = create_media url: url, key: key
    m.as_json
    id = Media.get_id(url)
    data = Pender::Store.current.read(id, :json)
    
    assert data['metrics']['facebook']['share_count'] > 0
  end

  test "should return empty metrics data upon error" do
    Media.stubs(:request_metrics_from_facebook).raises(StandardError.new)
    url = 'https://meedan.com'
    m = create_media url: url
    m.as_json
    id = Media.get_id(url)
    data = Pender::Store.current.read(id, :json)
    assert_equal({}, data['metrics']['facebook'])
  end

  test "should get metrics from Facebook when URL has non-ascii" do
    Media.unstub(:request_metrics_from_facebook)
    fb_config = PenderConfig.get('facebook_test_app') || PenderConfig.get('facebook_app')
    PenderConfig.current = nil
    key = create_api_key application_settings: { config: { facebook_app: fb_config }}
    ApiKey.current = key
    assert_nothing_raised do
      response = Media.request_metrics_from_facebook("http://www.facebook.com/people/\u091C\u0941\u0928\u0948\u0926-\u0905\u0939\u092E\u0926/100014835514496")
      assert_kind_of Hash, response
    end
  end

  test "should get Facebook metrics from crowdtangle when it's a Facebook item" do
    post_id = '172685102050_10157701432562051'
    crowdtangle_data = {"result"=>{"posts"=>[{"platformId"=>post_id,"account"=>{"id"=>33862, "name"=>"Account name", "handle"=>"accoutn"},"statistics"=>{"actual"=>{"likeCount"=>30813, "shareCount"=>1640, "commentCount"=>457, "loveCount"=>5131, "wowCount"=>74, "hahaCount"=>543, "sadCount"=>2, "angryCount"=>1, "thankfulCount"=>0, "careCount"=>136}, "expected"=>{"likeCount"=>12142, "shareCount"=>641, "commentCount"=>446, "loveCount"=>2044, "wowCount"=>48, "hahaCount"=>10, "sadCount"=>3, "angryCount"=>2, "thankfulCount"=>0, "careCount"=>71}}}]}}
    Media.unstub(:request_metrics_from_facebook)
    Media.any_instance.stubs(:get_crowdtangle_id).returns(post_id)
    Media.stubs(:crowdtangle_request).returns(crowdtangle_data)
    ['https://www.facebook.com/172685102050/photos/a.406269382050/10157701432562051/', 'https://www.facebook.com/permalink.php?story_fbid=10157697779652051&id=172685102050'].each do |url|
      m = create_media url: url
      m.as_json
      id = Media.get_id(url)
      data = Pender::Store.current.read(id, :json)
      assert data['metrics']['facebook']['share_count'] > 0
    end
    Media.any_instance.unstub(:get_crowdtangle_id)
    Media.unstub(:crowdtangle_request)
  end

  {
    missing_app_id: { body: "{\"error\":{\"message\":\"Missing client_id parameter.\",\"type\":\"OAuthException\",\"code\":101}}", code: "400", message: "Bad Request"},
    invalid_app_secret: { body: "{\"error\":{\"message\":\"Error validating client secret.\",\"type\":\"OAuthException\",\"code\":1}}", code: "400", message: "Bad Request"},
    api_limit_reached: { body: "{\"error\":{\"message\":\"(#4) Application request limit reached\",\"type\":\"OAuthException\",\"is_transient\":true,\"code\":4}}", code: "403", message: "Forbidden"}
  }.each do |error, response_info|
    test "should raise retry error when fails to get fb metrics and #{error}" do
      Sidekiq::Testing.fake!
      key = create_api_key application_settings: { config: { facebook_app: '1111:2222' }}

      url = 'https://www.example.com/'
      m = create_media url: url, key: key
      Media.unstub(:request_metrics_from_facebook)
      WebMock.enable!
      WebMock.disable_net_connect!(allow: 'graph.facebook.com')
      WebMock.stub_request(:any, /graph.facebook.com\/oauth\/access_token/).to_return(body: {"access_token":"token"}.to_json)
      WebMock.stub_request(:any, "https://graph.facebook.com/?id=#{url}&fields=engagement&access_token=token").to_return(body: response_info[:body], status: response_info[:code].to_i)
      PenderAirbrake.stubs(:notify)
      assert_raises Pender::RetryLater do
        assert_nil Media.request_metrics_from_facebook(url)
      end
      WebMock.disable!
      PenderAirbrake.unstub(:notify)
      Sidekiq::Worker.clear_all
      Semaphore.new('1111').unlock
    end
  end

  test "should use second facebook_app when fails to get fb metrics and api limit reached" do
    Sidekiq::Testing.fake!
    fb_app = ENV['facebook_app']
    url = 'https://www.example.com/'
    m = create_media url: url
    Media.unstub(:request_metrics_from_facebook)
    Media.any_instance.stubs(:unsafe?).returns(false)
    response_info = { body: "{\"error\":{\"message\":\"(#4) Application request limit reached\",\"type\":\"OAuthException\",\"is_transient\":true,\"code\":4}}", code: "403", message: "Forbidden"}
    ENV['facebook_app'] = '1111:2222;3333:4444'
    WebMock.enable!
    WebMock.disable_net_connect!(allow: 'graph.facebook.com')
    WebMock.stub_request(:any, 'https://graph.facebook.com/oauth/access_token?client_id=1111&client_secret=2222&grant_type=client_credentials').to_return(body: {"access_token":"app1_token"}.to_json)
    WebMock.stub_request(:any, 'https://graph.facebook.com/oauth/access_token?client_id=3333&client_secret=4444&grant_type=client_credentials').to_return(body: {"access_token":"app2_token"}.to_json)
    WebMock.stub_request(:any, "https://graph.facebook.com/?id=#{url}&fields=engagement&access_token=app1_token").to_return(body: response_info[:body], status: response_info[:code].to_i)
    WebMock.stub_request(:any, "https://graph.facebook.com/?id=#{url}&fields=engagement&access_token=app2_token").to_return(body: {"engagement":{"reaction_count":15}}.to_json, status: 200)
    PenderAirbrake.stubs(:notify)
    assert_raises Pender::RetryLater do
      Media.request_metrics_from_facebook(url)
    end
    assert_equal 15, Media.request_metrics_from_facebook(url)['reaction_count']
    WebMock.disable!
    PenderAirbrake.unstub(:notify)
    Media.any_instance.unstub(:unsafe?)
    Semaphore.new('1111').unlock
    Semaphore.new('3333').unlock
    Sidekiq::Worker.clear_all
    ENV['facebook_app'] = fb_app
  end

  test "should return nil when fb metrics returns a permanent error" do
    url = 'https://www.example.com/'
    {
      10 => 'Requires Facebook page permissions',
      100 => 'Unsupported get request. Facebook object ID does not support this operation',
      803 => 'The Facebook object ID is not correct or invalid'
    }.each do |code, message|
      assert Media.fb_metrics_error(:permanent, url, { 'code' => code, 'message' => message}), "The error code `#{code}` should be listed as permanent error"
    end
  end

  test "should use api key config to get metrics and storage config if present" do
    Media.unstub(:request_metrics_from_facebook)

    url = 'https://www.google.com/'

    ApiKey.current = PenderConfig.current = Pender::Store.current = nil
    key_config = { facebook_app: 'fb-app-id:fb-app-secret', storage_endpoint: PenderConfig.get('storage_endpoint'), storage_access_key: PenderConfig.get('storage_access_key'), storage_secret_key: PenderConfig.get('storage_secret_key'), storage_bucket: 'my-bucket', storage_bucket_region: PenderConfig.get('storage_bucket_region'), storage_video_bucket: 'video-bucket', storage_video_asset_path: 'http://video.path', storage_medias_asset_path: 'http://medias.path'}
    api_key = create_api_key application_settings: { config: key_config }
    assert_raises Pender::RetryLater do
      Media.get_metrics_from_facebook(url, api_key.id, 10)
    end
    assert_equal api_key, ApiKey.current
    assert_equal api_key.settings[:config][:facebook_app], PenderConfig.current(:facebook_app)
    %w(endpoint access_key secret_key bucket bucket_region video_bucket video_asset_path medias_asset_path).each do |key|
      assert_equal api_key.settings[:config]["storage_#{key}"], PenderConfig.current("storage_#{key}"), "Expected #{key}"
      assert_equal api_key.settings[:config]["storage_#{key}"], Pender::Store.current.instance_variable_get(:@storage)[key]
    end
  end

  test "should not store crowdtangle data when id on response is different from request" do
    crowdtangle_data = {"result"=>{"posts"=>[{"platformId"=>"537326876328007_4451640454896610","platform"=>"Facebook","type"=>"native_video","message"=>"Attention‼️ ","account"=>{"id"=>1852061,"platform"=>"Facebook","platformId"=>"537326876328007"}}]}}
    Media.unstub(:request_metrics_from_facebook)
    Media.any_instance.stubs(:get_crowdtangle_id).returns('563555033699775_1866497603524209')
    Media.stubs(:crowdtangle_request).returns(crowdtangle_data)
    url = 'https://www.facebook.com/watch/?v=1866497603524209'
    m = create_media url: url
    m.as_json
    id = Media.get_id(url)
    data = Pender::Store.current.read(id, :json)
    assert_match /Cannot get data/, data['raw']['crowdtangle']['error']['message']
    Media.any_instance.unstub(:get_crowdtangle_id)
    Media.unstub(:crowdtangle_request)
  end

  test "should handle error when can't notify webhook" do
    webhook_info = { 'webhook_url' => 'http://invalid.webhook', 'webhook_token' => 'test' }
    assert_equal false, Media.notify_webhook('metrics', 'http://example.com', {}, webhook_info)
  end
end
