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
    @request.path = '/api/medias.html?url=https://new.speakbridge.io/medias/embed/viber/1/403'
    assert_equal '<script src="http://foo.bar/api/medias.js?url=https://new.speakbridge.io/medias/embed/viber/1/403" type="text/javascript"></script>', embed_url
  end

  test "should get embed URL with refresh" do
    @request.path = '/api/medias.html?url=http://twitter.com/meedan&refresh=1'
    assert_equal '<script src="http://foo.bar/api/medias.js?refresh=1&url=http://twitter.com/meedan" type="text/javascript"></script>', embed_url
  end

  test "should not crash if jsonld content is null" do
    m = create_media url: 'https://www.facebook.com/dina.samak/posts/10153679232246949'
    assert_nothing_raised do
      get_jsonld_data(m)
    end
  end

  test "should not crash if jsonld content is not valid" do
    JSON.stubs(:parse).raises(JSON::ParserError)
    m = create_media url: 'http://www.example.com'
    doc = ''
    open('test/data/page-with-json-ld.html') { |f| doc = f.read }
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML(doc))
    m.data = Media.minimal_data(m)
    assert_nothing_raised do
      m.get_jsonld_data(m)
    end
    Media.any_instance.unstub(:doc)
    JSON.unstub(:parse)
  end
end
