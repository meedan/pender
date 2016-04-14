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
    get :index, url: 'http://meedan.com', format: :json
    assert_response :success
  end

  test "should be able to fetch HTML without token" do
    get :index, url: 'http://meedan.com', format: :html
    assert_response :success
  end

  test "should show error message if Twitter user does not exist" do
    authenticate_with_token
    get :index, url: 'https://twitter.com/caiosba32153623', format: :json
    assert_response 400
    assert_equal 'User not found.', JSON.parse(@response.body)['data']['message']
  end

  test "should return HTML error" do
    get :index, url: 'https://www.facebook.com/Meedan-54421674438/?fref=ts', format: :html
    assert_response 400
  end
end
