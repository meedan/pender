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
    sleep 1
    get :index, url: 'https://twitter.com/caiosba/status/742779467521773568', refresh: '1', format: :json
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
    assert_match /Koala::Facebook::ClientError: Unsupported get request/, data['error']['message']
    assert_equal 100, data['error']['code']
    assert_equal 'facebook', data['provider']
    assert_equal 'profile', data['type']
    assert_not_nil data['embed_tag']
  end

  test "should return error message on hash if url does not exist 3" do
    authenticate_with_token
    get :index, url: 'https://www.instagram.com/blih_blih/', format: :json
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
    get :index, url: 'http://foo.com/blah_blah', format: :json
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
    get :index, url: 'http://foo.com/blah_blah', format: :json
    assert_response 200
    data = JSON.parse(@response.body)['data']
    assert_equal 'RuntimeError', data['error']['message']
    assert_equal 'UNKNOWN', data['error']['code']
    Media.any_instance.unstub(:as_json)
  end

  test "should return message with HTML error" do
    get :index, url: 'https://www.facebook.com/non-sense-stuff-892173891273', format: :html
    assert_response 200

    assert_match /Koala::Facebook::ClientError: Unsupported get request/, response.body
  end

  test "should return message with HTML error 2" do
    File.stubs(:read).raises
    get :index, url: 'http://foo.com/blah_blah', format: :html
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
    get :index, url: 'https://meedan.checkdesk.org/en/report/2161', format: :html
    assert_response :success
    assert_match /meedan_iframes.parent.min.js/, response.body
    assert_no_match /pender-title/, response.body
  end

  test "should render default HTML if not provided by oEmbed" do
    get :index, url: 'http://twitter.com/caiosba', format: :html
    assert_response :success
    assert_match /pender-title/, response.body
  end

  test "should return custom oEmbed format" do
    get :index, url: 'https://meedan.checkdesk.org/en/report/2161', format: :oembed
    assert_response :success
    assert_not_nil response.body
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
  end

  test "should return API limit reached error" do
    Twitter::REST::Client.any_instance.stubs(:user).raises(Twitter::Error::TooManyRequests)
    Twitter::Error::TooManyRequests.any_instance.stubs(:rate_limit).returns(OpenStruct.new(reset_in: 123))

    authenticate_with_token
    get :index, url: 'http://twitter.com/caiosba', format: :json
    assert_response 429
    assert_equal 123, JSON.parse(@response.body)['data']['error']['message']

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
    assert_equal 'The URL is not valid', JSON.parse(@response.body)['data']['error']['message']
  end

  test "should show error message if url not found" do
    authenticate_with_token
    get :index, url: 'http://not-valid', format: :json
    assert_response 400
    assert_match /The URL is not valid/, JSON.parse(@response.body)['data']['error']['message']
  end

  test "should show error message if url valid but cannot parse it" do
    authenticate_with_token
    get :index, url: 'http://asdfasdf.com', format: :json
    assert_response 200
    data = JSON.parse(@response.body)['data']
    assert_equal 'Timeout::Error: execution expired', data['error']['message']
    assert_equal 10, data['error']['code']
  end

  test "should show error message if url valid but inexistent 2" do
    authenticate_with_token
    get :index, url: 'http://www.yahii.co', format: :json
    assert_response 400
    data = JSON.parse(@response.body)['data']
    assert_equal 'The URL is not valid', data['error']['message']
    assert_equal 4, data['error']['code']
  end

  test "should show error message if url valid but inexistent with ssl" do
    authenticate_with_token
    get :index, url: 'https://asdfasdf.com', format: :json
    assert_response 400
    data = JSON.parse(@response.body)['data']
    assert_equal 'The URL is not valid', data['error']['message']
    assert_equal 4, data['error']['code']
  end

end
