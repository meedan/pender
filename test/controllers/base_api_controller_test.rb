require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class BaseApiControllerTest < ActionController::TestCase
  def setup
    super
    @controller = Api::V1::BaseApiController.new
  end

  test "should return only enabled archivers" do
    authenticate_with_token
    get :about, params: { format: :json }
    assert_response :success
    response = JSON.parse(@response.body)
    assert_equal [{"key"=>"archive_is", "label"=>"Archive.is"}, {"key"=>"archive_org", "label"=>"Archive.org"}, {"key"=>"perma_cc", "label"=>"Perma.cc"}, {"key"=>"video", "label"=>"Video"}], response['data']['archivers']

    enabled = Media::ENABLED_ARCHIVERS
    Media.const_set(:ENABLED_ARCHIVERS, enabled.select { |archiver| archiver[:key] != 'archive_is' })
    get :about, params: { format: :json }
    response = JSON.parse(@response.body)
    assert_equal [{"key"=>"archive_org", "label"=>"Archive.org"}, {"key"=>"perma_cc", "label"=>"Perma.cc"}, {"key"=>"video", "label"=>"Video"}], response['data']['archivers']
    Media.send(:remove_const, :ENABLED_ARCHIVERS)
    Media.const_set(:ENABLED_ARCHIVERS, enabled)
  end

  test "should return unauthorized if not authenticated" do
    get :about, params: { format: :json }
    assert_response 401
    response = JSON.parse(@response.body)
    assert_equal 'error', response['type']
    assert_match 'unauthorized', response['data']['message'].downcase
  end

  test "should return info when memory report is enabled" do
    MemoryProfiler::Results.any_instance.stubs(:pretty_print)
    api_key = create_api_key application_settings: { config: {memory_report: true} }
    authenticate_with_token(api_key)

    get :about, params: { format: :json }
    assert_response :success
    response = JSON.parse(@response.body)
    assert_equal 'Keep', response['data']['name']
    MemoryProfiler::Results.any_instance.unstub(:pretty_print)
  end

  test "should send basic tracing information for api key" do
    api_key = create_api_key
    authenticate_with_token(api_key)


    TracingService.expects(:add_attributes_to_current_span).with({
      'app.api_key' => api_key.id
    })

    get :about, params: { format: :json }
  end
end
