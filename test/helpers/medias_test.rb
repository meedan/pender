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
    assert_equal timeout, m.timeout_value

    PenderConfig.current = nil
    m = Media.new url: url, key: key1
    assert_equal 10, m.timeout_value

    PenderConfig.current = nil
    m = Media.new url: url, key: key2
    assert_equal timeout, m.timeout_value

    PenderConfig.current = nil
    m = Media.new url: url, key: key3
    assert_equal timeout, m.timeout_value

  end

  test 'should validate proxies subkeys' do
    default_proxy = CONFIG['proxy']
    api_key = create_api_key

    ApiKey.current = api_key
    assert_equal default_proxy, Media.valid_proxy('proxy')
    assert_nil Media.valid_proxy('ytdl_proxy')

    proxy = { 'host' => 'my-proxy.mine', 'port' => '1111', 'user_prefix' => 'my-user-prefix', 'pass' => '12345', 'country_prefix' => '-cc-', 'session_prefix' => '-ss-' }
    video_proxy = { 'host' => 'my-video-proxy.mine', 'port' => '1111', 'user_prefix' => 'my-user-prefix', 'pass' => '12345' }
    api_key.application_settings = { config: { proxy: proxy, ytdl_proxy: video_proxy }}; api_key.save
    ApiKey.current = api_key
    PenderConfig.current = nil
    assert_equal proxy, Media.valid_proxy('proxy')
    assert_equal video_proxy, Media.valid_proxy('ytdl_proxy')

    proxy_with_empty_values = { 'host' => 'my-proxy.mine', 'port' => '1111', 'user_prefix' => '', 'pass' => nil, 'session_prefix' => '-ss-' }
    video_proxy_with_empty_values= { 'host' => 'my-video-proxy.mine', 'user_prefix' => '', 'pass' => nil }
    api_key.application_settings = { config: { proxy: proxy_with_empty_values, ytdl_proxy: video_proxy_with_empty_values }}; api_key.save
    ApiKey.current = api_key
    PenderConfig.current = nil
    assert_nil Media.valid_proxy('proxy')
    assert_nil Media.valid_proxy('ytdl_proxy')
  end

  test 'should upload images to s3 and update media data' do
    urls = %w(
      https://meedan.com
      https://twitter.com/meedan/status/1292864876361154561
      https://www.youtube.com/watch?v=qAogQrF7NFs
    )
    urls.each do |url|
      id = Media.get_id(url)
      m = Media.new url: url
      data = m.as_json
      assert_match /\/medias\/#{id}\/author_picture.(jpg|png)/, data[:author_picture], "Can't get `author_picture` from url #{url}"
      assert_match /\/medias\/#{id}\/picture.(jpg|png)/, data[:picture], "Can't get `picture` from url #{url}"
    end
  end

end
