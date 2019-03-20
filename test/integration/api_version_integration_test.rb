require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class ApiVersionIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    super
  end

  test "should get about" do
    assert_recognizes({ controller: 'api/v1/base_api', action: 'about', format: 'json' }, { path: 'api/about', method: :get })
  end

  test "should not recognize route to about with other format" do
    assert_raise ActionController::RoutingError do
      Rails.application.routes.recognize_path('api/about.html', { method: :get })
    end
  end

  test "should not recognize route to about with other method" do
    [:post, :delete].each do |method|
      assert_raise ActionController::RoutingError do
        Rails.application.routes.recognize_path('api/about', { method: method })
      end
    end
  end

end
