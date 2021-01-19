require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class BaseApiControllerTest < ActionController::TestCase
  def setup
    super
    @controller = Api::V1::BaseApiController.new
  end

  test "should return only enabled archivers" do
    authenticate_with_token
    get :about, format: :json
    assert_response :success
    response = JSON.parse(@response.body)
    assert_equal [{"key"=>"archive_is", "label"=>"Archive.is"}, {"key"=>"archive_org", "label"=>"Archive.org"}, {"key"=>"perma_cc", "label"=>"Perma.cc"}, {"key"=>"video", "label"=>"Video"}], response['data']['archivers']

    Media::ARCHIVERS['archive_is'][:enabled] = false
    get :about, format: :json
    response = JSON.parse(@response.body)
    assert_equal [{"key"=>"archive_org", "label"=>"Archive.org"}, {"key"=>"perma_cc", "label"=>"Perma.cc"}, {"key"=>"video", "label"=>"Video"}], response['data']['archivers']
  end

  test "should return unauthorized if not authenticated" do
    get :about, format: :json
    assert_response 401
    response = JSON.parse(@response.body)
    assert_equal 'error', response['type']
    assert_equal I18n.t(:unauthorized), response['data']['message']
  end

end
