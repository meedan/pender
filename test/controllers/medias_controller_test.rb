require_relative '../test_helper'
require 'time'

class MediasControllerTest < ActionController::TestCase
  def setup
    super
    @controller = Api::V1::MediasController.new
  end

  test "should be able to fetch HTML without token" do
    get :index, params: { url: 'https://meedan.com/post/annual-report-2022', format: :html }
    assert_response :success
  end

  test "should ask to refresh cache" do
    authenticate_with_token
    get :index, params: { url: 'https://meedan.com/post/annual-report-2022', refresh: '1', format: :json }
    first_parsed_at = Time.parse(JSON.parse(@response.body)['data']['parsed_at']).to_i
    get :index, params: { url: 'https://meedan.com/post/annual-report-2022', format: :html }
    name = Media.get_id('https://meedan.com/post/annual-report-2022')
    [:html, :json].each do |type|
      assert Pender::Store.current.read(name, type), "#{name}.#{type} is missing"
    end
    sleep 1
    get :index, params: { url: 'https://meedan.com/post/annual-report-2022', refresh: '1', format: :json }
    assert !Pender::Store.current.read(name, :html), "#{name}.html should not exist"
    second_parsed_at = Time.parse(JSON.parse(@response.body)['data']['parsed_at']).to_i
    assert second_parsed_at > first_parsed_at
  end

  test "should not ask to refresh cache" do
    authenticate_with_token
    get :index, params: { url: 'https://meedan.com/post/annual-report-2022', refresh: '0', format: :json }
    first_parsed_at = Time.parse(JSON.parse(@response.body)['data']['parsed_at']).to_i
    sleep 1
    get :index, params: { url: 'https://meedan.com/post/annual-report-2022', format: :json }
    second_parsed_at = Time.parse(JSON.parse(@response.body)['data']['parsed_at']).to_i
    assert_equal first_parsed_at, second_parsed_at
  end

  test "should ask to refresh cache with html format" do
    authenticate_with_token
    url = 'https://meedan.com/post/annual-report-2022'
    get :index, params: { url: url, refresh: '1', format: :html }
    id = Media.get_id(url)
    first_parsed_at = Pender::Store.current.get(id, :html).last_modified
    sleep 1
    get :index, params: { url: url, refresh: '1', format: :html }
    second_parsed_at = Pender::Store.current.get(id, :html).last_modified
    assert second_parsed_at > first_parsed_at
  end

  test "should not ask to refresh cache with html format" do
    authenticate_with_token
    url = 'https://meedan.com/post/annual-report-2022'
    id = Media.get_id(url)
    get :index, params: { url: url, refresh: '0', format: :html }
    first_parsed_at = Pender::Store.current.get(id, :html).last_modified
    sleep 1
    get :index, params: { url: url, format: :html }
    second_parsed_at = Pender::Store.current.get(id, :html).last_modified
    assert_equal first_parsed_at, second_parsed_at
  end

  test "should return error message on hash if url does not exist" do
    authenticate_with_token
    get :index, params: { url: 'https://www.instagram.com/kjdahsjkdhasjdkhasjk/', format: :json }
    assert_response 200
    data = JSON.parse(@response.body)['data']
    assert_not_nil data['error']['message']
    assert_equal Lapis::ErrorCodes::const_get('UNKNOWN'), data['error']['code']
    assert_equal 'instagram', data['provider']
    assert_equal 'profile', data['type']
    assert_not_nil data['embed_tag']
  end

  # TODO Must be fixed on #8794
  #test "should return error message on hash if url does not exist 4" do
  #  authenticate_with_token
  #  get :index, params: { url: 'https://www.instagram.com/p/blih_blih/', format: :json
  #  assert_response 200
  #  data = JSON.parse(@response.body)['data']
  #  assert_equal 'RuntimeError: Net::HTTPNotFound: Not Found', data['error']['message']
  #  assert_equal 5, data['error']['code']
  #  assert_equal 'instagram', data['provider']
  #  assert_equal 'item', data['type']
  #  assert_not_nil data['embed_tag']
  #end

  test "should return error message on hash if url does not exist 5" do
    authenticate_with_token
    get :index, params: { url: 'http://example.com/blah_blah', format: :json }
    assert_response 200
    data = JSON.parse(@response.body)['data']
    assert_equal 'Parser::PageItem::HtmlFetchingError: Could not parse this media', data['error']['message']
    assert_equal 5, data['error']['code']
    assert_equal 'page', data['provider']
    assert_equal 'item', data['type']
    assert_not_nil data['embed_tag']
  end

  test "should return error message on hash if as_json raises error" do
    Media.any_instance.stubs(:as_json).raises(RuntimeError)
    authenticate_with_token
    get :index, params: { url: 'http://example.com/', format: :json }
    assert_response 200
    data = JSON.parse(@response.body)['data']
    assert_equal 'RuntimeError', data['error']['message']
    assert_equal Lapis::ErrorCodes::const_get('UNKNOWN'), data['error']['code']
  end

  test "should not return error message on HTML format response" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML("<meta property='og:title' content='Log In or Sign Up to View'>"))
    get :index, params: { url: 'https://www.facebook.com/caiosba/posts/3588207164560845', format: :html, refresh: '1' }
    assert_response 200
    assert_match('Login required to see this profile', assigns(:media).data['error']['message'])
  end

  test "should return message with HTML error 2" do
    url = 'https://example.com'
    id = Media.get_id(url)
    Pender::Store.any_instance.stubs(:read).with(id, :json)
    Pender::Store.any_instance.stubs(:read).with(id, :html).raises
    get :index, params: { url: url, format: :html }
    assert_response 200

    assert_match /Could not parse this media/, response.body
  end

  test "should be able to fetch JS without token" do
    get :index, params: { url: 'http://meedan.com', format: :js }
    assert_response :success
  end

  test "should allow iframe" do
    get :index, params: { url: 'http://meedan.com', format: :js }
    assert !@response.headers.include?('X-Frame-Options')
  end

  test "should have JS format" do
    get :index, params: { url: 'http://meedan.com', format: :js }
    assert_response :success
    assert_not_nil assigns(:caller)
  end

  test "should render custom HTML if provided by oEmbed" do
    oembed = '{"version":"1.0","type":"rich","html":"<script type=\"text/javascript\"src=\"https:\/\/meedan.com\/meedan_iframes\/js\/meedan_iframes.parent.min.js?style=width%3A%20100%25%3B&amp;u=\/en\/embed\/3300\"><\/script>"}'
    response = 'mock';response.stubs(:code).returns('200');response.stubs(:body).returns(oembed)
    Media.any_instance.stubs(:oembed_get_data_from_url).returns(response);response.stubs(:header).returns({})
    get :index, params: { url: 'http://meedan.com', format: :html }
    assert_response :success
    assert_match /meedan_iframes.parent.min.js/, response.body
    assert_no_match /pender-title/, response.body
  end

  test "should render default HTML if not provided by oEmbed" do
    get :index, params: { url: 'https://meedan.com/post/annual-report-2022', format: :html }
    assert_response :success
    assert_match /pender-title/, response.body
  end

  test "should return timeout error" do
    api_key = create_api_key application_settings: { config: { timeout: '0.001' }}
    authenticate_with_token(api_key)

    get :index, params: { url: 'https://meedan.com/post/annual-report-2022', format: :json }
    assert_response 200
    assert_equal 'Timeout', JSON.parse(@response.body)['data']['error']['message']
  end

  test "should render custom HTML if provided by parser" do
    get :index, params: { url: 'https://twitter.com/caiosba/status/742779467521773568', format: :html }
    assert_response :success
    assert_match /twitter-tweet/, response.body
    assert_no_match /pender-title/, response.body
  end

  test "should respect timeout" do
    url = 'https://meedan.com/'
    api_key = create_api_key application_settings: { config: { timeout: 0.00001 }}
    authenticate_with_token(api_key)
    get :index, params: { url: url, format: :json }
    assert_equal 'Timeout', JSON.parse(@response.body)['data']['error']['message']
    assert_response 200
  end

  test "should return success even if media could not be instantiated" do
    authenticate_with_token
    Media.expects(:new).raises(Net::ReadTimeout)
    get :index, params: { url: 'https://meedan.com', format: :json, refresh: '1' }
    assert_response :success
  end

  test "should allow URL with non-latin characters" do
    authenticate_with_token
    url = 'https://martinoei.com/article/13071/林鄭月娥-居港夠廿年嗎？'
    get :index, params: { url: url }
    assert_response :success
  end

  test "should clear cache for multiple URLs sent as array" do
    authenticate_with_token
    url1 = 'https://meedan.com'
    url2 = 'https://meedan.com/post/annual-report-2022'

    normalized_url1 = 'https://meedan.com/'
    normalized_url2 = 'https://meedan.com/post/annual-report-2022'

    id1 = Media.get_id(normalized_url1)
    id2 = Media.get_id(normalized_url2)

    [:html, :json].each do |type|
      [id1, id2].each do |id|
        assert !Pender::Store.current.read(id, type), "#{id}.#{type} should not exist"
      end
    end

    get :index, params: { url: url1 }
    get :index, params: { url: url2 }
    [:html, :json].each do |type|
      [id1, id2].each do |id|
        assert Pender::Store.current.read(id, type), "#{id}.#{type} is missing"
      end
    end

    delete :delete, params: { url: [normalized_url1, normalized_url2], format: 'json' }
    assert_response :success
    [:html, :json].each do |type|
      [id1, id2].each do |id|
        assert !Pender::Store.current.read(id, type), "#{id}.#{type} is missing"
      end
    end
  end

  test "should return invalid url when the certificate has error" do
    url = 'https://www.poynter.org/2017/european-policy-makers-are-not-done-with-facebook-google-and-fake-news-just-yet/465809/'
    RequestHelper.stubs(:request_url).with(url, 'Get').raises(OpenSSL::SSL::SSLError)

    authenticate_with_token
    get :index, params: { url: url, format: :json }
    assert_response 400
    assert_equal 'The URL is not valid', JSON.parse(response.body)['data']['message']
  end

  test "should return invalid url if has SSL Error on follow_redirections" do
    url = 'https://asdfglkjh.ee'
    RequestHelper.stubs(:validate_url).with(url).returns(true)
    RequestHelper.stubs(:request_url).with(url, 'Get').raises(OpenSSL::SSL::SSLError)

    authenticate_with_token
    get :index, params: { url: url, format: :json }
    assert_response 400
    assert_equal 'The URL is not valid', JSON.parse(response.body)['data']['message']
  end

  test "should return invalid url when is there is only the scheme" do
    variations = %w(
      http
      http:
      http:/
      http://
      https
      https:
      https:/
      https://
    )

    authenticate_with_token
    variations.each do |url|
      get :index, params: { url: url, format: :json }
      assert_response 400
      assert_equal 'The URL is not valid', JSON.parse(response.body)['data']['message']
    end
  end

  test "should redirect and remove unsupported parameters if format is HTML and URL is the only supported parameter provided" do
    url = 'https://meedan.com/post/annual-report-2022'

    get :index, params: { url: url, foo: 'bar', format: :html }
    assert_response 302
    assert_equal 'api/medias.html?url=https%3A%2F%2Fmeedan.com%2Fpost%2Fannual-report-2022', @response.redirect_url.split('/', 4).last

    get :index, params: { url: url, foo: 'bar', format: :js }
    assert_response 200

    get :index, params: { url: url, foo: 'bar', format: :html, refresh: '1' }
    assert_response 200

    get :index, params: { url: url, format: :html }
    assert_response 200
  end

  test "should not parse url with userinfo" do
    authenticate_with_token
    url = 'http://noha@meedan.com'
    get :index, params: { url: url, format: :json }
    assert_response 400
    assert_equal 'The URL is not valid', JSON.parse(response.body)['data']['message']
  end

  test "should return timeout error with minimal data if cannot parse url" do
    stub_configs({ 'timeout' => 0.1 }) do
      url = 'https://meedan.com/post/annual-report-2022'
      PenderSentry.stubs(:notify).never

      authenticate_with_token
      get :index, params: { url: url, refresh: '1', format: :json }
      assert_response 200
      Media.minimal_data(OpenStruct.new(url: url)).except(:parsed_at).each_pair do |key, value|
        assert_equal value, JSON.parse(@response.body)['data'][key]
      end
      error = JSON.parse(@response.body)['data']['error']
      assert_equal 'Timeout', error['message']
      assert_equal Lapis::ErrorCodes::const_get('TIMEOUT'), error['code']
    end
  end

  test "should not archive in any archiver when no archiver parameter is sent" do
    Media.any_instance.unstub(:archive_to_archive_org)

    a = create_api_key application_settings: { 'webhook_url': 'https://example.com/webhook.php', 'webhook_token': 'test' }
    WebMock.enable!
    allowed_sites = lambda{ |uri| !['web.archive.org'].include?(uri.host) }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/web/123456/test' })
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    authenticate_with_token(a)
    url = 'https://meedan.com/post/annual-report-2022'
    get :index, params: { url: url, format: :json }
    id = Media.get_id(url)
    assert_equal({}, Pender::Store.current.read(id, :json)[:archives].sort.to_h)
  ensure
    WebMock.disable!
  end

  test "should not archive when archiver parameter is none" do
    Media.any_instance.unstub(:archive_to_archive_org)
    a = create_api_key application_settings: { 'webhook_url': 'https://example.com/webhook.php', 'webhook_token': 'test' }
    WebMock.enable!
    allowed_sites = lambda{ |uri| !['web.archive.org'].include?(uri.host) }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/web/123456/test' })
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    authenticate_with_token(a)
    url = 'https://meedan.com/post/annual-report-2022'
    get :index, params: { url: url, archivers: 'none', format: :json }
    id = Media.get_id(url)
    assert_equal({}, Pender::Store.current.read(id, :json)[:archives])
  ensure
    WebMock.disable!
  end

  [['perma_cc'], ['archive_org'], ['perma_cc', 'archive_org'], [' perma_cc ', ' archive_org ']].each do |archivers|
    test "should archive on `#{archivers}`" do
      Media.any_instance.unstub(:archive_to_archive_org)
      Media.any_instance.unstub(:archive_to_perma_cc)
      Media.stubs(:get_available_archive_org_snapshot).returns(nil)
      Media::ARCHIVERS['perma_cc'][:enabled] = true

      a = create_api_key application_settings: { config: { 'perma_cc_key': 'my-perma-key' },  'webhook_url': 'https://example.com/webhook.php', 'webhook_token': 'test' }
      WebMock.enable!
      allowed_sites = lambda{ |uri| !['api.perma.cc', 'web.archive.org'].include?(uri.host) }
      WebMock.disable_net_connect!(allow: allowed_sites)

      WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
      WebMock.stub_request(:any, /api.perma.cc/).to_return(body: { guid: 'perma-cc-guid-1' }.to_json)
      WebMock.stub_request(:post, /web.archive.org\/save/).to_return(body: {job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' }.to_json)
      WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'success', timestamp: 'timestamp'}.to_json)

      url = 'https://meedan.com/post/annual-report-2022'
      archived = {"perma_cc"=>{"location"=>"http://perma.cc/perma-cc-guid-1"}, "archive_org"=>{"location"=>"https://web.archive.org/web/timestamp/#{url}"}}

      authenticate_with_token(a)
      get :index, params: { url: url, archivers: archivers.join(','), format: :json }
      id = Media.get_id(url)
      data = Pender::Store.current.read(id, :json)
      archivers.each do |archiver|
        archiver.strip!
        assert_equal(archived[archiver], data[:archives][archiver])
      end
    ensure
      WebMock.disable!
    end
  end

  test "should show the urls that couldn't be enqueued when bulk parsing" do
    WebMock.enable!
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    a = create_api_key application_settings: { 'webhook_url' => 'https://example.com/webhook.php', 'webhook_token' => 'test' }
    authenticate_with_token(a)

    url1 = 'https://meedan.com/post/annual-report-2022'
    url2 = 'https://meedan.com'
    MediaParserWorker.stubs(:perform_async).with(url1, a.id, false, nil)
    MediaParserWorker.stubs(:perform_async).with(url2, a.id, false, nil).raises(RuntimeError)
    post :bulk, params: { url: [url1, url2], format: :json }
    assert_response :success
    assert_equal({"enqueued"=>[url1], "failed"=>[url2]}, JSON.parse(@response.body)['data'])
  ensure
    WebMock.disable!
  end

  test "should enqueue, parse and notify with error when invalid url" do
    webhook_info = { 'webhook_url' => 'https://example.com/webhook.php', 'webhook_token' => 'test' }
    a = create_api_key application_settings: webhook_info
    authenticate_with_token(a)
    url1 = 'http://invalid-url'
    url2 = 'not-url'
    Media.stubs(:notify_webhook).with('error', url1, { error: { message: 'The URL is not valid', code: Lapis::ErrorCodes::const_get('INVALID_VALUE') }}, webhook_info)
    Media.stubs(:notify_webhook).with('error', url2, { error: { message: 'The URL is not valid', code: Lapis::ErrorCodes::const_get('INVALID_VALUE') }}, webhook_info)
    post :bulk, params: { url: [url1, url2], format: :json }
    assert_response :success
    assert_equal({"enqueued"=>[url1, url2], "failed"=>[]}, JSON.parse(@response.body)['data'])
  end

  test "should parse multiple URLs sent as list" do
    authenticate_with_token
    url1 = 'https://meedan.com/check'
    url2 = 'https://meedan.com/mission'
    id1 = Media.get_id(url1)
    id2 = Media.get_id(url2)
    assert_nil Pender::Store.current.read(id1, :json)
    assert_nil Pender::Store.current.read(id2, :json)

    WebMock.enable!
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    a = create_api_key application_settings: { 'webhook_url': 'https://example.com/webhook.php', 'webhook_token': 'test' }
    authenticate_with_token(a)
    post :bulk, params: { url: "#{url1}, #{url2}", format: :json }
    assert_response :success
    sleep 2
    data1 = Pender::Store.current.read(id1, :json)
    assert !data1['title'].blank?
    data2 = Pender::Store.current.read(id2, :json)
    assert !data2['title'].blank?
  ensure
    WebMock.disable!
  end

  test "should enqueue, parse and notify with error when timeout" do
    Sidekiq::Testing.fake!
    a = create_api_key application_settings: { config: { timeout: '0.001' }, 'webhook_url' => 'https://example.com/webhook.php', 'webhook_token' => 'test' }

    authenticate_with_token(a)

    url = 'https://meedan.com'
    id = Media.get_id(url)
    timeout_error = {"message" => "Timeout", "code" => Lapis::ErrorCodes::const_get('TIMEOUT')}

    assert_equal 0, MediaParserWorker.jobs.size
    post :bulk, params: { url: url, format: :json, refresh: '1' }
    assert_response :success
    assert_equal({"enqueued"=>[url], "failed"=>[]}, JSON.parse(@response.body)['data'])
    assert_equal 1, MediaParserWorker.jobs.size
    assert_equal url, MediaParserWorker.jobs[0]['args'][0]

    assert_nil Pender::Store.current.read(id, :json)

    args_checker = ->(type, url, data, settings) {
      assert_equal timeout_error, data['error']
    }
    Media.stub(:notify_webhook, args_checker) do
      MediaParserWorker.drain
    end
  end

  test "should return data with error message if can't parse" do
    webhook_info = { 'webhook_url': 'https://example.com/webhook.php', 'webhook_token': 'test' }
    url = 'https://meedan.com/post/annual-report-2022'
    parse_error = { error: { "message"=>"RuntimeError: RuntimeError", "code"=>5}}
    required_fields = Media.required_fields(OpenStruct.new(url: url))
    Media.stubs(:required_fields).returns(required_fields)
    Media.stubs(:notify_webhook)
    Media.stubs(:notify_webhook).with('media_parsed', url, parse_error.merge(required_fields).with_indifferent_access, webhook_info)
    Media.any_instance.stubs(:parse).raises(RuntimeError)

    a = create_api_key application_settings: webhook_info
    authenticate_with_token(a)
    post :bulk, params: { url: url, format: :json }
    assert_response :success
    assert_equal({"enqueued"=>[url], "failed"=>[]}, JSON.parse(@response.body)['data'])
  end

  test "should return data with error message if can't instantiate" do
    Sidekiq::Testing.fake!
    webhook_info = { 'webhook_url' => 'https://example.com/webhook.php', 'webhook_token' => 'test' }
    a = create_api_key application_settings: webhook_info
    authenticate_with_token(a)

    assert_equal 0, MediaParserWorker.jobs.size

    url = 'https://meedan.com/post/annual-report-2022'
    post :bulk, params: { url: url, format: :json }

    assert_response :success
    assert_equal({"enqueued"=>[url], "failed"=>[]}, JSON.parse(@response.body)['data'])
    assert_equal 1, MediaParserWorker.jobs.size

    parse_error = { error: { "message"=>"OpenSSL::SSL::SSLError", "code"=> Lapis::ErrorCodes::const_get('UNKNOWN')}}
    minimal_data = Media.minimal_data(OpenStruct.new(url: url)).merge(title: url)
    Media.stubs(:minimal_data).returns(minimal_data)
    Media.stubs(:notify_webhook).with('media_parsed', url, minimal_data.merge(parse_error), webhook_info)
    Media.any_instance.stubs(:get_canonical_url).raises(OpenSSL::SSL::SSLError)
    MediaParserWorker.drain
  end

  test "should remove empty parameters" do
    get :index, params: { empty: '', notempty: 'Something' }
    assert !@controller.params.keys.include?('empty')
    assert @controller.params.keys.include?('notempty')
  end

  test "should remove empty headers" do
    @request.headers['X-Empty'] = ''
    @request.headers['X-Not-Empty'] = 'Something'
    get :index, params: {}
    assert @request.headers['X-Empty'].nil?
    assert !@request.headers['X-Not-Empty'].nil?
  end

  test "should return build as a custom header" do
    get :index, params: {}
    assert_not_nil @response.headers['X-Build']
  end

  test "should return default api version as a custom header" do
    get :index, params: {}
    assert_match /v1$/, @response.headers['Accept']
  end

  test "should rescue and unlock url when raises error" do
    authenticate_with_token
    url = 'https://meedan.com/post/annual-report-2022'
    assert !Semaphore.new(url).locked?
    [:js, :json, :html].each do |format|
      @controller.stubs("render_as_#{format}".to_sym).raises(RuntimeError.new('error'))
      get :index, params: { url: url, format: format }
      assert !Semaphore.new(url).locked?
      assert_equal url, JSON.parse(response.body)['data']['url']
      assert_equal 'error', JSON.parse(response.body)['data']['error']['message']
      @controller.unstub("render_as_#{format}".to_sym)
    end
  end

  test "should rescue and unlock url when raises error on store" do
    authenticate_with_token
    url = 'https://meedan.com/post/annual-report-2022'
    assert !Semaphore.new(url).locked?
    Pender::Store.any_instance.stubs(:read).raises(RuntimeError.new('error'))
    [:js, :json, :html].each do |format|
      assert_nothing_raised do
        get :index, params: { url: url, format: format }
        assert !Semaphore.new(url).locked?
        assert_response 200
        assert_equal url, JSON.parse(response.body)['data']['url']
        assert_equal 'error', JSON.parse(response.body)['data']['error']['message']
      end
    end
  end

  test "should unlock url after timeout" do
    url = 'https://meedan.com/post/annual-report-2022'
    s = Semaphore.new(url)
    assert !s.locked?

    api_key = create_api_key application_settings: { config: { timeout: '0.001' }}
    PenderConfig.current = nil
    ApiKey.current = api_key

    s.lock
    sleep 5
    assert !s.locked?
    s.unlock

    PenderConfig.current = nil
    api_key.application_settings = { config: { timeout: '30' }}; api_key.save
    s.lock
    sleep 5
    assert s.locked?
    s.unlock
  end

  test "should return error if URL is not safe" do
    authenticate_with_token
    url = 'http://malware.wicar.org/data/ms14_064_ole_not_xp.html' # More examples: https://www.wicar.org/test-malware.html
    RequestHelper.stubs(:validate_url).with(url).returns(true)
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    WebMock.enable!
    WebMock.disable_net_connect!

    WebMock.stub_request(:get, /malware.wicar.org/).to_return(status: 200, body: "<title>Test Malware!</title>")

    safebrowsing_response = {
      "matches": [{
        "threatType": "MALWARE",
        "platformType": "WINDOWS",
        "threatEntryType": "URL",
        "threat": {"url": url},
        "threatEntryMetadata": {
          "entries": [{
            "key": "malware_threat_type",
            "value": "landing"
         }]
        },
        "cacheDuration": "300.000s"
      }]
    }
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(body: safebrowsing_response.to_json)

    get :index, params: { url: url, format: 'json' }
    response = JSON.parse(@response.body)
    assert_equal 'error', response['type']
    assert_equal 'Unsafe URL', response['data']['message']
  end

  test "should cache json and html on file" do
    authenticate_with_token
    url = 'https://meedan.com/post/annual-report-2022'
    id = Media.get_id(url)
    [:html, :json].each do |type|
      assert !Pender::Store.current.read(id, type), "#{id}.#{type} should not exist"
    end

    get :index, params: { url: url, format: :html }
    [:html, :json].each do |type|
      assert Pender::Store.current.read(id, type), "#{id}.#{type} is missing"
    end
  end

  test "should not throw nil error" do
    authenticate_with_token
    url = 'https://most-popular-lists.blogspot.com/2019/07/fishermen-diokno-were-fooled-us-into.html'
    get :index, params: { url: url, format: 'json' }
    assert_match /fishermen/, JSON.parse(@response.body)['data']['title'].downcase
  end

  test "should get config from api key if defined" do
    @controller.stubs(:unload_current_config)
    api_key = create_api_key application_settings: { config: { }}
    authenticate_with_token(api_key)

    get :index, params: { url: 'http://meedan.com', format: :json }
    assert_response 200
    assert_nil PenderConfig.get('key_for_test')

    api_key.application_settings = { config: { key_for_test: 'api_config_value' }}; api_key.save
    get :index, params: { url: 'http://meedan.com', format: :json }
    assert_response 200
    assert_equal 'api_config_value', PenderConfig.get('key_for_test')
  end

  test "should add url on title when timeout" do
    api_key = create_api_key application_settings: { config: { timeout: '0.001' }}
    authenticate_with_token(api_key)

    url = 'https://example.com'
    get :index, params: { url: url, format: :json }
    assert_response 200
    assert_equal url, JSON.parse(@response.body)['data']['title']
  end

  test "should return 200 when raises error parsing" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    WebMock.stub_request(:any, /example.com/).to_raise(Errno::ECONNRESET.new('Exception from WebMock'))

    authenticate_with_token
    url = 'https://example.com/fail-to-parse'
    get :index, params: { url: url, format: :json }
    assert_response 200
    assert_equal url, JSON.parse(@response.body)['data']['title']
    assert_equal Lapis::ErrorCodes::const_get('UNKNOWN'), JSON.parse(@response.body)['data']['error']['code']
  end

  test "should return 200 when duplicated url" do
    authenticate_with_token
    url = 'https://example.com/duplicated'
    Semaphore.any_instance.stubs(:locked?).returns(true)
    get :index, params: { url: url, format: :json }
    assert_response 200
    assert_equal url, JSON.parse(@response.body)['data']['title']
    assert_equal Lapis::ErrorCodes::const_get('DUPLICATED'), JSON.parse(@response.body)['data']['error']['code']
  end

  test "should refresh cache even if ID changes" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    Media.stubs(:get_id).returns('foo', 'bar', 'foo', 'bar')
    Pender::Store.current.write('foo', :json, { title: 'Meedan 1' })
    Pender::Store.current.write('bar', :json, { title: 'Meedan 2' })

    url = 'https://meedan.com'
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html><title>Meedan 1</title></html>')

    authenticate_with_token

    get :index, params: { url: url, format: :json, refresh: 1 }
    assert_equal 'Meedan 1', JSON.parse(@response.body)['data']['title']
  end
end

class MediasControllerUnitTest < ActionController::TestCase
  def setup
    isolated_setup
    @controller = Api::V1::MediasController.new
  end

  def teardown
    isolated_teardown
  end

  test "should not cache if error message" do
    class MockMedia
      RESPONSE = {
        "error" => {
          "message" => "Fake error for testing",
          "code"=> 4,
        },
        "title" => "some throwaway title"
      }
      def initialize(**args); end

      def data
        RESPONSE
      end

      def as_json(**args)
        RESPONSE
      end
    end
    Media.stubs(:new).returns(MockMedia.new)

    RequestHelper.stubs(:validate_url).returns(true)
    Semaphore.any_instance.stubs(:locked?).returns(false)

    id = Media.get_id('https://www.instagram.com/fakeaccount/')
    Pender::Store.any_instance.expects(:write).with(id).never

    Pender::Store.current.delete(id, :json)
    assert Pender::Store.current.read(id, :json).blank?

    authenticate_with_token
    get :index, params: { url: 'https://www.instagram.com/fakeaccount/', format: :json }
    assert_response 200

    assert Pender::Store.current.read(id, :json).blank?
  end
end
