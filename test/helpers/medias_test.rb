require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class MediasHelperTest < ActionView::TestCase
  def request
    req = ActionController::TestRequest.new 
    req.host = 'foo.bar'
    req.path = '/api/medias.html?url=http://twitter.com/meedan'
    req
  end

  test "should get embed URL" do
    assert_equal '<script src="http://foo.bar/api/medias.js?url=http://twitter.com/meedan"></script>', embed_url
  end
end
