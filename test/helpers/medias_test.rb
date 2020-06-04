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
    @request.path = '/api/medias.html?url=https://twitter.com/meedan/status/1214263820484521985'
    assert_equal '<script src="http://foo.bar/api/medias.js?url=https://twitter.com/meedan/status/1214263820484521985" type="text/javascript"></script>', embed_url
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

  test 'should verify value on published_time and use second option if available' do
    assert_equal '2018-08-21 00:19:25 +0000', verify_published_time('1534810765').to_s
    assert_equal '2018-08-20 22:05:01 +0000', verify_published_time('1534810765', '1534802701').to_s
  end

  test "should get config from api key or default config" do
    url = 'http://example.com'
    timeout = CONFIG['timeout']
    key1 = create_api_key application_settings: { config: { timeout: 10 }}
    key2 = create_api_key application_settings: {}
    key3 = create_api_key

    m = Media.new url: url
    assert_equal timeout, Media.get_config(m)[:timeout]

    m.key = key1
    assert_equal 10, Media.get_config(m)[:timeout]

    m.key = key2
    assert_equal timeout, Media.get_config(m)[:timeout]

    m.key = key3
    assert_equal timeout, Media.get_config(m)[:timeout]

  end

end
