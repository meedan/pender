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
    cache_file = File.join('public', 'cache', Rails.env, "#{name}.html" )
    assert File.exist?(cache_file)
    sleep 1
    get :index, url: 'https://twitter.com/caiosba/status/742779467521773568', refresh: '1', format: :json
    assert !File.exist?(cache_file)
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
    cache_file = File.join('public', 'cache', Rails.env, "#{name}.html" )
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
    cache_file = File.join('public', 'cache', Rails.env, "#{name}.html" )
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
    stub_configs({ 'timeout' => 10 })
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
    get :index, url: 'http://twitter.com/caiosba', format: :oembed
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
    get :index, url: 'http://twitter.com/caiosba', format: :html
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
    get :index, url: 'http://twitter.com/caiosba', format: :json
    assert_response 200
    assert_equal 'Timeout', JSON.parse(@response.body)['data']['error']['message']
  end

  test "should return API limit reached error" do
    Twitter::REST::Client.any_instance.stubs(:user).raises(Twitter::Error::TooManyRequests)
    Twitter::Error::TooManyRequests.any_instance.stubs(:rate_limit).returns(OpenStruct.new(reset_in: 123))

    authenticate_with_token
    get :index, url: 'http://twitter.com/caiosba', format: :json
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
    cachefile1 = File.join('public', 'cache', Rails.env, "#{id1}.html")
    cachefile2 = File.join('public', 'cache', Rails.env, "#{id2}.html")
    
    assert !File.exist?(cachefile1)
    assert !File.exist?(cachefile2)
    assert_nil Rails.cache.read(id1)
    assert_nil Rails.cache.read(id2)
    
    get :index, url: url1
    get :index, url: url2
    assert File.exist?(cachefile1)
    assert File.exist?(cachefile2)
    assert_not_nil Rails.cache.read(id1)
    assert_not_nil Rails.cache.read(id2)
    
    delete :delete, url: [url1, url2], format: 'json'
    assert_response :success
    assert !File.exist?(cachefile1)
    assert !File.exist?(cachefile2)
    assert_nil Rails.cache.read(id1)
    assert_nil Rails.cache.read(id2)
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
    Rails.cache.delete(id)
    get :index, url: url, format: :oembed
    assert_response :success
    data = JSON.parse(response.body)['data']
    assert_not_nil data['error']['message']
    Media.unstub(:as_oembed)
  end

  test "should respond to oembed format when data is on cache" do
    url = 'http://www.scmp.com/news/hong-kong/politics/article/2071886/crucial-next-hong-kong-leader-have-central-governments-trust'
    id = Digest::MD5.hexdigest(url)

    assert_nil Rails.cache.read(id)
    get :index, url: url, format: :oembed
    assert_not_nil assigns(:media)
    assert_response :success
    assert_nil JSON.parse(response.body)['error']

    assert_not_nil Rails.cache.read(assigns(:id))
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

end
