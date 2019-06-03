require_relative '../test_helper'
require 'time'

class MediasControllerTest < ActionController::TestCase
  def setup
    super
    @controller = Api::V1::MediasController.new
  end

  test "should return error if url is not provided" do
    authenticate_with_token
    get :index, format: :json
    assert_response 400
  end

  test "should return error if not authenticated" do
    get :index, url: 'http://meedan.com', format: :json
    assert_response 401
  end

  test "should parse media" do
    authenticate_with_token
    get :index, url: 'http://twitter.com/meedan', format: :json
    assert_response :success
  end

  test "should be able to fetch HTML without token" do
    get :index, url: 'http://twitter.com/meedan', format: :html
    assert_response :success
  end

  test "should ask to refresh cache" do
    authenticate_with_token
    get :index, url: 'https://twitter.com/caiosba/status/742779467521773568', refresh: '1', format: :json
    first_parsed_at = Time.parse(JSON.parse(@response.body)['data']['parsed_at']).to_i
    get :index, url: 'https://twitter.com/caiosba/status/742779467521773568', format: :html
    name = Digest::MD5.hexdigest('https://twitter.com/caiosba/status/742779467521773568')
    html_cache_file = File.join('public', "cache#{ENV['TEST_ENV_NUMBER']}", Rails.env, "#{name}.html" )
    json_cache_file = File.join('public', "cache#{ENV['TEST_ENV_NUMBER']}", Rails.env, "#{name}.json" )
    assert File.exist?(html_cache_file)
    assert File.exist?(json_cache_file)
    sleep 1
    get :index, url: 'https://twitter.com/caiosba/status/742779467521773568', refresh: '1', format: :json
    assert !File.exist?(html_cache_file)
    second_parsed_at = Time.parse(JSON.parse(@response.body)['data']['parsed_at']).to_i
    assert second_parsed_at > first_parsed_at
  end

  test "should not ask to refresh cache" do
    authenticate_with_token
    get :index, url: 'https://twitter.com/caiosba/status/742779467521773568', refresh: '0', format: :json
    first_parsed_at = Time.parse(JSON.parse(@response.body)['data']['parsed_at']).to_i
    sleep 1
    get :index, url: 'https://twitter.com/caiosba/status/742779467521773568', format: :json
    second_parsed_at = Time.parse(JSON.parse(@response.body)['data']['parsed_at']).to_i
    assert_equal first_parsed_at, second_parsed_at
  end

  test "should ask to refresh cache with html format" do
    authenticate_with_token
    url = 'https://speakbridge.io/medias/embed/viber/1/403'
    get :index, url: url, refresh: '1', format: :html
    name = Digest::MD5.hexdigest(url)
    cache_file = File.join('public', "cache#{ENV['TEST_ENV_NUMBER']}", Rails.env, "#{name}.html" )
    first_parsed_at = File.mtime(cache_file)
    sleep 1
    get :index, url: url, refresh: '1', format: :html
    second_parsed_at = File.mtime(cache_file)
    assert second_parsed_at > first_parsed_at
  end

  test "should not ask to refresh cache with html format" do
    authenticate_with_token
    url = 'https://speakbridge.io/medias/embed/viber/1/403'
    name = Digest::MD5.hexdigest(url)
    cache_file = File.join('public', "cache#{ENV['TEST_ENV_NUMBER']}", Rails.env, "#{name}.html" )
    get :index, url: url, refresh: '0', format: :html
    first_parsed_at = File.mtime(cache_file)
    sleep 1
    get :index, url: url, format: :html
    second_parsed_at = File.mtime(cache_file)
    assert_equal first_parsed_at, second_parsed_at
  end

  test "should return error message on hash if url does not exist" do
    authenticate_with_token
    get :index, url: 'https://twitter.com/caiosba32153623', format: :json
    assert_response 200
    data = JSON.parse(@response.body)['data']
    assert_equal 'Twitter::Error::NotFound: User not found.', data['error']['message']
    assert_equal 50, data['error']['code']
    assert_equal 'twitter', data['provider']
    assert_equal 'profile', data['type']
    assert_not_nil data['embed_tag']
  end

  test "should return error message on hash if url does not exist 2" do
    authenticate_with_token
    get :index, url: 'https://www.facebook.com/blah_blah', format: :json
    assert_response 200
    data = JSON.parse(@response.body)['data']
    assert_match 'Login required to see this profile', data['error']['message']
    assert_equal 'facebook', data['provider']
    assert_equal 'profile', data['type']
    assert_not_nil data['embed_tag']
  end

  test "should return error message on hash if url does not exist 3" do
    authenticate_with_token
    get :index, url: 'https://www.instagram.com/kjdahsjkdhasjdkhasjk/', format: :json
    assert_response 200
    data = JSON.parse(@response.body)['data']
    assert_equal 'RuntimeError: Could not parse this media', data['error']['message']
    assert_equal 5, data['error']['code']
    assert_equal 'instagram', data['provider']
    assert_equal 'profile', data['type']
    assert_not_nil data['embed_tag']
  end

  test "should return error message on hash if url does not exist 4" do
    authenticate_with_token
    get :index, url: 'https://www.instagram.com/p/blih_blih/', format: :json
    assert_response 200
    data = JSON.parse(@response.body)['data']
    assert_equal 'RuntimeError: Net::HTTPNotFound: Not Found', data['error']['message']
    assert_equal 5, data['error']['code']
    assert_equal 'instagram', data['provider']
    assert_equal 'item', data['type']
    assert_not_nil data['embed_tag']
  end

  test "should return error message on hash if url does not exist 5" do
    authenticate_with_token
    get :index, url: 'http://example.com/blah_blah', format: :json
    assert_response 200
    data = JSON.parse(@response.body)['data']
    assert_equal 'RuntimeError: Could not parse this media', data['error']['message']
    assert_equal 5, data['error']['code']
    assert_equal 'page', data['provider']
    assert_equal 'item', data['type']
    assert_not_nil data['embed_tag']
  end

  test "should return error message on hash if url does not exist 6" do
    authenticate_with_token
    get :index, url: 'https://twitter.com/caiosba/status/0000000000000', format: :json
    assert_response 200
    data = JSON.parse(@response.body)['data']
    assert_equal 'Twitter::Error::NotFound: No data available for specified ID.', data['error']['message']
    assert_equal 8, data['error']['code']
    assert_equal 'twitter', data['provider']
    assert_equal 'item', data['type']
    assert_not_nil data['embed_tag']
  end

  test "should parse facebook url when url does not exist 7" do
    authenticate_with_token
    get :index, url: 'https://www.facebook.com/ahlam.alialshamsi/posts/000000000000000', format: :json
    assert_response 200
    data = JSON.parse(@response.body)['data']
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
    assert_not_nil data['embed_tag']
  end

  test "should return error message on hash if url does not exist 8" do
    Media.any_instance.stubs(:as_json).raises(RuntimeError)
    authenticate_with_token
    get :index, url: 'http://example.com/', format: :json
    assert_response 200
    data = JSON.parse(@response.body)['data']
    assert_equal 'RuntimeError', data['error']['message']
    assert_equal 'UNKNOWN', data['error']['code']
    Media.any_instance.unstub(:as_json)
  end

  test "should not return error message on HTML format response" do
    get :index, url: 'https://www.facebook.com/non-sense-stuff-892173891273', format: :html
    assert_response 200

    assert_match('Login required to see this profile', assigns(:media).data['error']['message'])
  end

  test "should return message with HTML error 2" do
    File.stubs(:read).raises
    get :index, url: 'http://example.com/', format: :html
    assert_response 200

    assert_match /Could not parse this media/, response.body
    File.unstub(:read)
  end

  test "should be able to fetch JS without token" do
    get :index, url: 'http://meedan.com', format: :js
    assert_response :success
  end

  test "should allow iframe" do
    get :index, url: 'http://meedan.com', format: :js
    assert !@response.headers.include?('X-Frame-Options')
  end

  test "should have JS format" do
    get :index, url: 'http://meedan.com', format: :js
    assert_response :success
    assert_not_nil assigns(:caller)
  end

  test "should return default oEmbed format" do
    get :index, url: 'https://twitter.com/CommitStrip', format: :oembed
    assert_response :success
  end

  test "should render custom HTML if provided by oEmbed" do
    oembed = '{"version":"1.0","type":"rich","html":"<script type=\"text/javascript\"src=\"https:\/\/meedan.com\/meedan_iframes\/js\/meedan_iframes.parent.min.js?style=width%3A%20100%25%3B&amp;u=\/en\/embed\/3300\"><\/script>"}'
    response = 'mock';response.stubs(:code).returns('200');response.stubs(:body).returns(oembed)
    Media.any_instance.stubs(:oembed_get_data_from_url).returns(response);response.stubs(:header).returns({})
    get :index, url: 'http://meedan.com', format: :html
    assert_response :success
    assert_match /meedan_iframes.parent.min.js/, response.body
    assert_no_match /pender-title/, response.body
    Media.any_instance.unstub(:oembed_get_data_from_url)
  end

  test "should render default HTML if not provided by oEmbed" do
    get :index, url: 'https://twitter.com/check', format: :html
    assert_response :success
    assert_match /pender-title/, response.body
  end

  test "should return custom oEmbed format" do
    oembed = '{"version":"1.0","type":"rich","html":"<script type=\"text/javascript\"src=\"https:\/\/meedan.com\/meedan_iframes\/js\/meedan_iframes.parent.min.js?style=width%3A%20100%25%3B&amp;u=\/en\/embed\/3300\"><\/script>"}'
    response = 'mock';response.stubs(:code).returns('200');response.stubs(:body).returns(oembed)
    Media.any_instance.stubs(:oembed_get_data_from_url).returns(response);response.stubs(:header).returns({})

    get :index, url: 'http://meedan.com', format: :oembed
    assert_response :success
    assert_not_nil response.body
    Media.any_instance.unstub(:oembed_get_data_from_url)
  end

  test "should create cache file" do
    Media.any_instance.expects(:as_json).once.returns({})
    get :index, url: 'http://twitter.com/caiosba', format: :html
    get :index, url: 'http://twitter.com/caiosba', format: :html
  end

  test "should return timeout error" do
    stub_configs({ 'timeout' => 0.001 })
    authenticate_with_token
    get :index, url: 'https://twitter.com/IronMaiden', format: :json
    assert_response 200
    assert_equal 'Timeout', JSON.parse(@response.body)['data']['error']['message']
  end

  test "should return API limit reached error" do
    Twitter::REST::Client.any_instance.stubs(:user).raises(Twitter::Error::TooManyRequests)
    Twitter::Error::TooManyRequests.any_instance.stubs(:rate_limit).returns(OpenStruct.new(reset_in: 123))

    authenticate_with_token
    get :index, url: 'https://twitter.com/anxiaostudio', format: :json
    assert_response 429
    assert_equal 123, JSON.parse(@response.body)['data']['message']

    Twitter::REST::Client.any_instance.unstub(:user)
    Twitter::Error::TooManyRequests.any_instance.unstub(:rate_limit)
  end

  test "should render custom HTML if provided by parser" do
    get :index, url: 'https://twitter.com/caiosba/status/742779467521773568', format: :html
    assert_response :success
    assert_match /twitter-tweet/, response.body
    assert_no_match /pender-title/, response.body
  end

  test "should show error message if is not a url" do
    authenticate_with_token
    get :index, url: 'not-valid', format: :json
    assert_response 400
    assert_equal 'The URL is not valid', JSON.parse(@response.body)['data']['message']
  end

  test "should show error message if url not found" do
    authenticate_with_token
    get :index, url: 'http://not-valid', format: :json
    assert_response 400
    assert_match /The URL is not valid/, JSON.parse(@response.body)['data']['message']
  end

  test "should respect timeout" do
    url = 'http://ca.ios.ba/files/others/test.php' # This link has a sleep(10) function
    stub_configs({ 'timeout' => 2 })
    authenticate_with_token
    start = Time.now.to_i
    get :index, url: url, format: :json
    time = Time.now.to_i - start
    assert time <= 3, "Expected it to take less than 3 seconds, but took #{time} seconds"
    assert_equal 'Timeout', JSON.parse(@response.body)['data']['error']['message']
    assert_response 200
  end

  test "should not try to clear upstream cache when generating cache for the first time" do
    CcDeville.any_instance.expects(:clear_cache).never
    get :index, url: 'https://twitter.com/caiosba/status/742779467521773568', format: :html
    CcDeville.any_instance.unstub(:clear_cache)
  end

  test "should not try to clear upstream cache when not asking to" do
    CcDeville.any_instance.expects(:clear_cache).never
    get :index, url: 'https://twitter.com/caiosba/status/742779467521773568', format: :html
    get :index, url: 'https://twitter.com/caiosba/status/742779467521773568', format: :html
    CcDeville.any_instance.unstub(:clear_cache)
  end

  test "should try to clear upstream cache when asking to" do
    url = 'https://twitter.com/caiosba/status/742779467521773568'
    encurl = CGI.escape(url)
    CcDeville.any_instance.expects(:clear_cache).with(CONFIG['public_url'] + '/api/medias.html?url=' + encurl).once
    CcDeville.any_instance.expects(:clear_cache).with(CONFIG['public_url'] + '/api/medias.html?refresh=1&url=' + encurl).once
    get :index, url: url, format: :html
    get :index, url: url, format: :html, refresh: '1'
    CcDeville.any_instance.unstub(:clear_cache)
  end

  test "should not try to clear upstream cache when there are no configs" do
    stub_configs({ 'cc_deville_token' => '', 'cc_deville_host' => '', 'cc_deville_httpauth' => '' }) do
      CcDeville.any_instance.expects(:clear_cache).never
      get :index, url: 'https://twitter.com/caiosba/status/742779467521773568', format: :html, refresh: '1'
    end
    CcDeville.any_instance.unstub(:clear_cache)
  end

  test "should return success even if media could not be instantiated" do
    authenticate_with_token
    Media.expects(:new).raises(Timeout::Error)
    get :index, url: 'http://ca.ios.ba/files/meedan/random.php', format: :json, refresh: '1'
    Media.unstub(:new)
    assert_response :success
  end

  test "should allow URL with non-latin characters" do
    authenticate_with_token
    url = 'https://martinoei.com/article/13071/林鄭月娥-居港夠廿年嗎？'
    get :index, url: url
    assert_response :success
  end

  test "should clear cache for multiple URLs sent as array" do
    authenticate_with_token
    url1 = 'http://ca.ios.ba'
    url2 = 'https://twitter.com/caiosba/status/742779467521773568'
    id1 = Media.get_id(url1)
    id2 = Media.get_id(url2)
    html_cachefile1 = File.join('public', "cache#{ENV['TEST_ENV_NUMBER']}", Rails.env, "#{id1}.html" )
    json_cachefile1 = File.join('public', "cache#{ENV['TEST_ENV_NUMBER']}", Rails.env, "#{id1}.json" )
    html_cachefile2 = File.join('public', "cache#{ENV['TEST_ENV_NUMBER']}", Rails.env, "#{id2}.html" )
    json_cachefile2 = File.join('public', "cache#{ENV['TEST_ENV_NUMBER']}", Rails.env, "#{id2}.json" )
    assert !File.exist?(html_cachefile1)
    assert !File.exist?(json_cachefile1)
    assert !File.exist?(html_cachefile2)
    assert !File.exist?(json_cachefile2)

    get :index, url: url1
    get :index, url: url2
    assert File.exist?(html_cachefile1)
    assert File.exist?(json_cachefile1)
    assert File.exist?(html_cachefile2)
    assert File.exist?(json_cachefile2)

    delete :delete, url: [url1, url2], format: 'json'
    assert_response :success
    assert !File.exist?(html_cachefile1)
    assert !File.exist?(json_cachefile1)
    assert !File.exist?(html_cachefile2)
    assert !File.exist?(json_cachefile2)
  end

  test "should not clear cache if not authenticated" do
    delete :delete, url: 'http://test.com', format: 'json'
    assert_response 401
  end

  test "should return custom oEmbed format for scmp url" do
    url = 'http://www.scmp.com/news/hong-kong/politics/article/2071886/crucial-next-hong-kong-leader-have-central-governments-trust'
    get :index, url: url, format: :oembed
    assert_response :success
    assert_not_nil response.body
    data = JSON.parse(response.body)
    assert_nil data['error']
  end

  test "should handle error when calls oembed format" do
    url = 'http://www.scmp.com/news/hong-kong/politics/article/2071886/crucial-next-hong-kong-leader-have-central-governments-trust'
    id = Digest::MD5.hexdigest(url)
    Media.stubs(:as_oembed).raises(StandardError)
    Pender::Store.new(id).delete(:json)
    get :index, url: url, format: :oembed
    assert_response :success
    data = JSON.parse(response.body)['data']
    assert_not_nil data['error']['message']
    Media.unstub(:as_oembed)
  end

  test "should respond to oembed format when data is on cache" do
    url = 'http://www.scmp.com/news/hong-kong/politics/article/2071886/crucial-next-hong-kong-leader-have-central-governments-trust'
    id = Digest::MD5.hexdigest(url)

    assert_nil Pender::Store.new(id).read(:json)
    get :index, url: url, format: :oembed
    assert_not_nil assigns(:media)
    assert_response :success
    assert_nil JSON.parse(response.body)['error']

    assert_not_nil Pender::Store.new(assigns(:id)).read(:json)
    get :index, url: url, format: :oembed
    assert_response :success
    assert_nil JSON.parse(response.body)['error']
  end

  test "should return invalid url when the certificate has error" do
    url = 'https://www.poynter.org/2017/european-policy-makers-are-not-done-with-facebook-google-and-fake-news-just-yet/465809/'
    Media.stubs(:request_url).with(url, 'Head').raises(OpenSSL::SSL::SSLError)

    authenticate_with_token
    get :index, url: url, format: :json
    assert_response 400
    assert_equal 'The URL is not valid', JSON.parse(response.body)['data']['message']

    Media.unstub(:request_url)
  end

  test "should return invalid url if has SSL Error on follow_redirections" do
    url = 'https://asdfglkjh.ee'
    Media.stubs(:validate_url).with(url).returns(true)
    Media.stubs(:request_url).with(url, 'Head').raises(OpenSSL::SSL::SSLError)

    authenticate_with_token
    get :index, url: url, format: :json
    assert_response 400
    assert_equal 'The URL is not valid', JSON.parse(response.body)['data']['message']

    Media.unstub(:validate_url)
    Media.unstub(:request_url)
  end

  test "should parse Facebook user profile with normalized urls" do
    authenticate_with_token
    get :index, url: 'https://facebook.com/caiosba', refresh: '1', format: :json
    first_parsed_at = Time.parse(JSON.parse(@response.body)['data']['parsed_at']).to_i
    sleep 1
    get :index, url: 'https://facebook.com/caiosba/', format: :json
    second_parsed_at = Time.parse(JSON.parse(@response.body)['data']['parsed_at']).to_i
    assert_equal first_parsed_at, second_parsed_at
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
      get :index, url: url, format: :json
      assert_response 400
      assert_equal 'The URL is not valid', JSON.parse(response.body)['data']['message']
    end
  end

  test "should redirect and remove unsupported parameters if format is HTML and URL is the only supported parameter provided" do
    url = 'https://twitter.com/caiosba/status/923697122855096320'
    
    get :index, url: url, foo: 'bar', format: :html
    assert_response 302
    assert_equal 'api/medias.html?url=https%3A%2F%2Ftwitter.com%2Fcaiosba%2Fstatus%2F923697122855096320', @response.redirect_url.split('/', 4).last

    get :index, url: url, foo: 'bar', format: :js
    assert_response 200

    get :index, url: url, foo: 'bar', format: :html, refresh: '1'
    assert_response 200

    get :index, url: url, format: :html
    assert_response 200
  end

  test "should not parse url with userinfo" do
    authenticate_with_token
    url = 'http://noha@meedan.com'
    get :index, url: url, format: :json
    assert_response 400
    assert_equal 'The URL is not valid', JSON.parse(response.body)['data']['message']
  end

  test "should return timeout error with minimal data if cannot parse url" do
    stub_configs({ 'timeout' => 0.1 })
    url = 'https://changescamming.net/halalan-2019/maria-ressa-to-bong-go-um-attend-ka-ng-senatorial-debate-di-yung-nagtatapon-ka-ng-pera'
    Airbrake.configuration.stubs(:api_key).returns('token')
    Airbrake.stubs(:notify).never

    authenticate_with_token
    get :index, url: url, refresh: '1', format: :json
    assert_response 200
    Media.minimal_data(OpenStruct.new(url: url)).except(:parsed_at).each_pair do |key, value|
      assert_equal value, JSON.parse(@response.body)['data'][key]
    end
    assert_equal({"message"=>"Timeout", "code"=>"TIMEOUT"}, JSON.parse(@response.body)['data']['error'])
    Airbrake.unstub(:notify)
  end

  test "should archive on all archivers when no parameter is sent" do
    Media.any_instance.unstub(:archive_to_archive_is)
    Media.any_instance.unstub(:archive_to_archive_org)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    WebMock.enable!
    allowed_sites = lambda{ |uri| !['archive.is', 'web.archive.org'].include?(uri.host) }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { location: 'http://archive.is/test' })
    WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/web/123456/test' })

    authenticate_with_token(a)
    url = 'https://twitter.com/meedan/status/1095693211681673218'
    get :index, url: url, format: :json
    id = Media.get_id(url)
    store = Pender::Store.new(id)
    assert_equal({"archive_is"=>{"location"=>"http://archive.is/test"}, "archive_org"=>{"location"=>"https://web.archive.org/web/123456/test"}}, store.read(:json)[:archives])

    WebMock.disable!
  end

  test "should not archive when parameter is none" do
    Media.any_instance.unstub(:archive_to_archive_is)
    Media.any_instance.unstub(:archive_to_archive_org)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    WebMock.enable!
    allowed_sites = lambda{ |uri| !['archive.is', 'web.archive.org'].include?(uri.host) }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { location: 'http://archive.is/test' })
    WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/web/123456/test' })

    authenticate_with_token(a)
    url = 'https://twitter.com/meedan/status/1095035775736078341'
    get :index, url: url, archivers: 'none', format: :json
    id = Media.get_id(url)
    assert_equal({}, Pender::Store.new(id).read(:json)[:archives])

    WebMock.disable!
  end

  [['archive_is'], ['archive_org'], ['archive_is', 'archive_org'], [' archive_is ', ' archive_org ']].each do |archivers|
    test "should archive on `#{archivers}`" do
      Media.any_instance.unstub(:archive_to_archive_is)
      Media.any_instance.unstub(:archive_to_archive_org)
      a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
      WebMock.enable!
      allowed_sites = lambda{ |uri| !['archive.is', 'web.archive.org'].include?(uri.host) }
      WebMock.disable_net_connect!(allow: allowed_sites)
      WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { location: 'http://archive.is/test' })
      WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/web/123456/test' })
      archived = {"archive_is"=>{"location"=>"http://archive.is/test"}, "archive_org"=>{"location"=>"https://web.archive.org/web/123456/test"}}

      authenticate_with_token(a)
      url = 'https://twitter.com/meedan/status/1095035552221540354'
      get :index, url: url, archivers: archivers.join(','), format: :json
      id = Media.get_id(url)
      store = Pender::Store.new(id)
      archivers.each do |archiver|
        archiver.strip!
        assert_equal(archived[archiver], store.read(:json)[:archives][archiver])
      end

      WebMock.disable!
    end
  end

  test "should show the urls that couldn't be enqueued when bulk parsing" do
    webhook_info = { 'webhook_url' => 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token' => 'test' }
    a = create_api_key application_settings: webhook_info
    authenticate_with_token(a)
    url1 = 'https://twitter.com/check/status/1102991340294557696'
    url2 = 'https://twitter.com/dimalb/status/1102928768673423362'
    MediaParserWorker.stubs(:perform_async).with(url1, a.id, false, nil)
    MediaParserWorker.stubs(:perform_async).with(url2, a.id, false, nil).raises(RuntimeError)
    post :bulk, url: [url1, url2], format: :json
    assert_response :success
    assert_equal({"enqueued"=>[url1], "failed"=>[url2]}, JSON.parse(@response.body)['data'])
    MediaParserWorker.unstub(:perform_async)
  end

  test "should enqueue, parse and notify with error when invalid url" do
    webhook_info = { 'webhook_url' => 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token' => 'test' }
    a = create_api_key application_settings: webhook_info
    authenticate_with_token(a)
    url1 = 'http://invalid-url'
    url2 = 'not-url'
    Media.stubs(:notify_webhook).with('error', url1, { error: { message: I18n.t(:url_not_valid), code: LapisConstants::ErrorCodes::const_get('INVALID_VALUE') }}, webhook_info)
    Media.stubs(:notify_webhook).with('error', url2, { error: { message: I18n.t(:url_not_valid), code: LapisConstants::ErrorCodes::const_get('INVALID_VALUE') }}, webhook_info)
    post :bulk, url: [url1, url2], format: :json
    assert_response :success
    assert_equal({"enqueued"=>[url1, url2], "failed"=>[]}, JSON.parse(@response.body)['data'])
    Media.unstub(:notify_webhook)
  end

  test "should parse multiple URLs sent as list" do
    authenticate_with_token
    url1 = 'https://twitter.com/meedan/status/1098927618626330625'
    url2 = 'https://twitter.com/meedan/status/1098556958590816260'
    id1 = Media.get_id(url1)
    id2 = Media.get_id(url2)
    store1 = Pender::Store.new(id1)
    store2 = Pender::Store.new(id2)
    assert_nil store1.read(:json)
    assert_nil store2.read(:json)

    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    authenticate_with_token(a)
    post :bulk, url: "#{url1}, #{url2}", format: :json
    assert_response :success
    sleep 2
    data1 = store1.read(:json)
    assert_match /The Checklist: How Google Fights #Disinformation/, data1['title']
    data2 = store2.read(:json)
    assert_match /The internet is as much about affirmation as information/, data2['title']
  end

  test "should enqueue, parse and notify with error when timeout" do
    webhook_info = { 'webhook_url' => 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token' => 'test' }
    a = create_api_key application_settings: webhook_info
    authenticate_with_token(a)

    url = 'https://ca.ios.ba/files/meedan/sleep.php'
    timeout_error = { error: { "message"=>"Timeout", "code"=>"TIMEOUT"}}
    minimal_data = Media.minimal_data(OpenStruct.new(url: url))
    Media.stubs(:minimal_data).with(OpenStruct.new(url: url)).returns(minimal_data)

    Media.stubs(:notify_webhook).with('media_parsed', url, minimal_data.merge(timeout_error), webhook_info)
    post :bulk, url: url, format: :json
    assert_response :success
    assert_equal({"enqueued"=>[url], "failed"=>[]}, JSON.parse(@response.body)['data'])
    Media.unstub(:notify_webhook)
    Media.unstub(:minimal_data)
  end

  test "should return data with error message if can't parse" do
    webhook_info = { 'webhook_url' => 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token' => 'test' }
    url = 'https://twitter.com/meedan/status/1102990605339316224'
    parse_error = { error: { "message"=>"RuntimeError: RuntimeError", "code"=>5}}
    required_fields = Media.required_fields(OpenStruct.new(url: url))
    Media.stubs(:required_fields).returns(required_fields)
    Media.stubs(:notify_webhook).with('media_parsed', url, parse_error.merge(required_fields).with_indifferent_access, webhook_info)
    Media.any_instance.stubs(:parse).raises(RuntimeError)
    a = create_api_key application_settings: webhook_info
    authenticate_with_token(a)
    post :bulk, url: url, format: :json
    assert_response :success
    assert_equal({"enqueued"=>[url], "failed"=>[]}, JSON.parse(@response.body)['data'])
    @store = Pender::Store.new(Media.get_id(self.original_url))
    Media.any_instance.unstub(:parse)
    Media.unstub(:notify_webhook)
    Media.unstub(:required_fields)
  end

  test "should return data with error message if can't instantiate" do
    Sidekiq::Testing.fake!
    webhook_info = { 'webhook_url' => 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token' => 'test' }
    url = 'https://twitter.com/meedan/status/1102990605339316224'
    a = create_api_key application_settings: webhook_info
    authenticate_with_token(a)

    assert_equal 0, MediaParserWorker.jobs.size
    post :bulk, url: url, format: :json
    assert_response :success
    assert_equal({"enqueued"=>[url], "failed"=>[]}, JSON.parse(@response.body)['data'])
    assert_equal 1, MediaParserWorker.jobs.size

    parse_error = { error: { "message"=>"OpenSSL::SSL::SSLError", "code"=>'UNKNOWN'}}
    minimal_data = Media.minimal_data(OpenStruct.new(url: url))
    Media.stubs(:minimal_data).returns(minimal_data)
    Media.stubs(:notify_webhook).with('media_parsed', url, minimal_data.merge(parse_error), webhook_info)
    Media.any_instance.stubs(:get_canonical_url).raises(OpenSSL::SSL::SSLError)
    MediaParserWorker.drain

    Media.any_instance.unstub(:get_canonical_url)
    Media.unstub(:notify_webhook)
    Media.unstub(:minimal_data)
  end

  test "should remove empty parameters" do
    get :index, empty: '', notempty: 'Something'
    assert !@controller.params.keys.include?('empty')
    assert @controller.params.keys.include?('notempty')
  end

  test "should remove empty headers" do
    @request.headers['X-Empty'] = ''
    @request.headers['X-Not-Empty'] = 'Something'
    get :index
    assert @request.headers['X-Empty'].nil?
    assert !@request.headers['X-Not-Empty'].nil?
  end

  test "should return build as a custom header" do
    get :index
    assert_not_nil @response.headers['X-Build']
  end

  test "should return default api version as a custom header" do
    get :index
    assert_match /v1$/, @response.headers['Accept']
  end

  test "should add data title on embed title metatag" do
    get :index, url: 'https://twitter.com/meedan/status/1110219801295765504', format: :html
    assert_response :success
    assert_match("<title>@InternetFF Our Meedani @WafHeikal will be...</title>", response.body)
  end

  test "should rescue and unlock url when raises error" do
    authenticate_with_token
    url = 'https://twitter.com/meedan/status/1118436001570086912'
    assert !Semaphore.new(url).locked?
    [:js, :json, :html, :oembed].each do |format|
      @controller.stubs("render_as_#{format}".to_sym).raises(RuntimeError.new('error'))
      get :index, url: url, format: format
      assert !Semaphore.new(url).locked?
      assert_response 400
      assert_equal 'error', JSON.parse(response.body)['data']['message']
      @controller.unstub("render_as_#{format}".to_sym)
    end
  end

  test "should return error if URL is not safe" do
    authenticate_with_token
    url = 'http://paytm.wishesrani.com/paytm-logo.png'
    get :index, url: url, format: 'json'
    response = JSON.parse(@response.body)
    assert_equal 'error', response['type']
  end

  test "should cache json and html on file" do
    authenticate_with_token
    url = 'https://twitter.com/meedan/status/1132948729424691201'
    id = Media.get_id(url)
    html = File.join('public', "cache#{ENV['TEST_ENV_NUMBER']}", Rails.env, "#{id}.html" )
    json = File.join('public', "cache#{ENV['TEST_ENV_NUMBER']}", Rails.env, "#{id}.json" )
    assert !File.exist?(html)
    assert !File.exist?(json)

    get :index, url: url, format: :html
    assert File.exist?(html)
    assert File.exist?(json)
  end
end
