require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class MediasHelperTest < ActionView::TestCase
  def setup
    super
    @request = ActionController::TestRequest.new 
    @request.host = 'foo.bar'
    @request
  end

  test "should get embed URL" do
    @request.path = '/api/medias.html?url=http://twitter.com/meedan'
    assert_equal '<script src="http://foo.bar/api/medias.js?url=http://twitter.com/meedan" type="text/javascript"></script>', embed_url
  end

  test "should get embed URL replacing only the first occurrence of medias" do
    @request.path = '/api/medias.html?url=https://speakbridge.io/medias/embed/milestone/M43/b156f9891c399ebab21dbdbf22987a8f723dadbb'
    assert_equal '<script src="http://foo.bar/api/medias.js?url=https://speakbridge.io/medias/embed/milestone/M43/b156f9891c399ebab21dbdbf22987a8f723dadbb" type="text/javascript"></script>', embed_url
  end

end
