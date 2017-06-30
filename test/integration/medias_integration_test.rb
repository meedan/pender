require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class MediasIntegrationTest < ActionDispatch::IntegrationTest
  test "should recognize route to delete" do
    assert_recognizes({ controller: 'api/v1/medias', action: 'delete', format: 'json' }, { path: 'api/medias', method: :delete })
  end

  test "should recognize route to delete using PURGE verb" do
    assert_recognizes({ controller: 'api/v1/medias', action: 'delete', format: 'json' }, { path: 'api/medias', method: :purge })
  end

  test "should recognize route to parse" do
    assert_recognizes({ controller: 'api/v1/medias', action: 'index', format: 'json' }, { path: 'api/medias', method: :get })
  end

  test "should not recognize route to delete with other format" do
    begin
      assert_not Rails.application.routes.recognize_path('api/medias.html', { method: 'delete' })
    rescue ActionController::RoutingError => error
      assert error.message.start_with? 'No route matches'
    end
  end

  test "should recognize route to parse with other format" do
    assert Rails.application.routes.recognize_path('api/medias.html', { method: 'get' })
    assert_recognizes({ controller: 'api/v1/medias', action: 'index', format: 'html' }, { path: 'api/medias.html', method: :get })
  end
end
