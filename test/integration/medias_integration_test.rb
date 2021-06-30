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

  test "should recognize route to bulk parse" do
    assert_recognizes({ controller: 'api/v1/medias', action: 'bulk', format: 'json' }, { path: 'api/medias', method: :post })
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

  test "should handle concurrency" do
    url = 'http://ca.ios.ba/files/meedan/sleep.php'
    threads = []

    threads << Thread.new do
      get "/api/medias.html?url=#{url}", params: {}
      assert_response :success
    end

    sleep 1

    threads << Thread.new do
      get "/api/medias.html?url=#{url}", params: {}
      assert_response :conflict
    end

    threads.map(&:join)
  end

  test "should normalize request URL" do
    url = '/api/medias.html?referrer=https%3A%2F%2Fmedium.com%2Fmedia%2F11d9292b164066cd07ec67d8090734cf%3FpostId%3D4308e5aacf6c&url=https%3A%2F%2Fcheckmedia.org%2F2222%2Fproject%2F691%2Fmedia%2F6923'
    get url, params: {}
    assert_response 302
    assert_equal 'api/medias.html?url=https%3A%2F%2Fcheckmedia.org%2F2222%2Fproject%2F691%2Fmedia%2F6923', @response.redirect_url.split('/', 4).last
  end
end
