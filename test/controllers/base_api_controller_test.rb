require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class BaseApiControllerTest < ActionController::TestCase
  def setup
    super
    @controller = Api::V1::BaseApiController.new
  end

  test "should respond to json" do
    assert_equal [:json], @controller.mimes_for_respond_to.keys
  end

  test "should filter parameters" do
    authenticate_with_token
    get :about, foo: 'bar', format: :json
    assert_equal ['foo'], @controller.send(:get_params).keys
  end

  test "should return enabled archivers and name" do
    authenticate_with_token
    get :about, format: :json
    assert_response :success
    response = JSON.parse(@response.body)
    assert_equal 'about', response['type']
    assert_equal 'Keep', response['data']['name']
    assert_equal [{"key"=>"archive_is", "label"=>"Archive.is"}, {"key"=>"archive_org", "label"=>"Archive.org"}], response['data']['archivers']

    Media::ARCHIVERS['archive_is'][:enabled] = false
    get :about, format: :json
    response = JSON.parse(@response.body)
    assert_equal 'about', response['type']
    assert_equal 'Keep', response['data']['name']
    assert_equal [{"key"=>"archive_org", "label"=>"Archive.org"}], response['data']['archivers']
  end


end
