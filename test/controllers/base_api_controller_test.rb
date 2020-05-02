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

  test "should return enabled archivers, name and version" do
    authenticate_with_token
    get :about, format: :json
    assert_response :success
    response = JSON.parse(@response.body)
    assert_equal ['data', 'type'], response.keys.sort
    assert_equal ['archivers', 'name', 'version'], response['data'].keys.sort
    assert_equal 'about', response['type']
    assert_equal 'Keep', response['data']['name']
    assert_equal VERSION, response['data']['version']
  end

  test "should return only enabled archivers" do
    authenticate_with_token
    get :about, format: :json
    assert_response :success
    response = JSON.parse(@response.body)
    assert_equal [{"key"=>"archive_is", "label"=>"Archive.is"}, {"key"=>"archive_org", "label"=>"Archive.org"}, {"key"=>"video", "label"=>"Video"}], response['data']['archivers']

    Media::ARCHIVERS['archive_is'][:enabled] = false
    get :about, format: :json
    response = JSON.parse(@response.body)
    assert_equal [{"key"=>"archive_org", "label"=>"Archive.org"}, {"key"=>"video", "label"=>"Video"}], response['data']['archivers']
  end

  test "should return Perma.cc as enabled archiver if perma_key is present" do
    authenticate_with_token

    assert_nil CONFIG.dig('perma_cc_key')

    get :about, format: :json
    assert_response :success
    response = JSON.parse(@response.body)
    assert_not_includes response['data']['archivers'], {"key"=>"perma_cc", "label"=>"Perma.cc"}

    CONFIG['perma_cc_key'] = 'perma-cc-key'
    Media.declare_archiver('perma_cc', [/^.*$/], :only, CONFIG.dig('perma_cc_key').present?)
    get :about, format: :json
    response = JSON.parse(@response.body)
    assert_includes response['data']['archivers'], {"key"=>"perma_cc", "label"=>"Perma.cc"}

    Media::ARCHIVERS['perma_cc'][:enabled] = CONFIG.dig('perma_cc_key').present?
    Media.unstub(:enabled_archivers)
    CONFIG.delete('perma_cc_key')
  end

end
