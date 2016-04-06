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
end
