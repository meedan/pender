require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

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

  test "should return error for unsupported media" do
    authenticate_with_token
    get :index, url: 'http://meedan.com', format: :json
    assert_response 400
  end

  test "should be able to fetch HTML without token" do
    get :index, url: 'http://twitter.com/meedan', format: :html
    assert_response :success
  end

  test "should show error message if Twitter user does not exist" do
    authenticate_with_token
    get :index, url: 'https://twitter.com/caiosba32153623', format: :json
    assert_response 400
    assert_equal 'Could not parse this media', JSON.parse(@response.body)['data']['message']
  end

  test "should return HTML error" do
    get :index, url: 'https://www.facebook.com/Meedan-54421674438/?fref=ts', format: :html
    assert_response 400
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

  test "should create cache file if does not exist" do
    get :index, url: 'http://twitter.com/caiosba', format: :html
    assert !assigns(:cache)
    get :index, url: 'http://twitter.com/caiosba', format: :html
    assert assigns(:cache)
  end

  test "should read from cache file if exists" do
    get :index, url: 'https://meedan.checkdesk.org/en/report/2161', format: :html
    assert !assigns(:cache)
    get :index, url: 'https://meedan.checkdesk.org/en/report/2161', format: :html
    assert assigns(:cache)
  end
end
