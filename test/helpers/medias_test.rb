require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class MediasHelperTest < ActionView::TestCase
  def setup
    super
    @request = ActionController::TestRequest.create(self.class)
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
    null_content = '<script type="application/ld+json">null</script>'
    m = create_media url: 'https://www.facebook.com/dina.samak/posts/10153679232246949'
    m.data = Media.minimal_data(m)
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML(null_content))
    assert_nothing_raised do
      get_jsonld_data(m)
    end
    Media.any_instance.unstub(:doc)
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

    key_with_timeout = create_api_key application_settings: { config: { timeout: 10 }}
    key_without_config = create_api_key application_settings: {}
    key_without_settings = create_api_key

    m = Media.new url: url
    assert_equal PenderConfig.get('timeout').to_i, m.timeout_value

    PenderConfig.current = nil
    m = Media.new url: url, key: key_with_timeout
    assert_equal key_with_timeout.application_settings[:config][:timeout], m.timeout_value

    PenderConfig.current = nil
    m = Media.new url: url, key: key_without_config
    assert_equal PenderConfig.get('timeout').to_i, m.timeout_value

    PenderConfig.current = nil
    m = Media.new url: url, key: key_without_settings
    assert_equal PenderConfig.get('timeout').to_i, m.timeout_value
  end

  test 'should validate proxies subkeys' do
    proxy_keys = [ 'host', 'port', 'user_prefix', 'pass', 'country_prefix', 'session_prefix' ]
    video_proxy_keys = [ 'host', 'port', 'user_prefix', 'pass' ]

    api_key = create_api_key

    proxy = { 'proxy_host' => 'my-proxy.mine', 'proxy_port' => '1111', 'proxy_user_prefix' => 'my-user-prefix', 'proxy_pass' => '12345', 'proxy_country_prefix' => '-cc-', 'proxy_session_prefix' => '-ss-' }
    video_proxy = { 'ytdl_proxy_host' => 'my-video-proxy.mine', 'ytdl_proxy_port' => '1111', 'ytdl_proxy_user_prefix' => 'my-user-prefix', 'ytdl_proxy_pass' => '12345' }
    api_key.application_settings = { config: proxy.merge(video_proxy) }; api_key.save
    ApiKey.current = api_key
    PenderConfig.current = nil
    proxy_keys.each do |key|
      assert_equal proxy["proxy_#{key}"], Media.valid_proxy('proxy')[key]
    end
    video_proxy_keys.each do |key|
      assert_equal video_proxy["ytdl_proxy_#{key}"], Media.valid_proxy('ytdl_proxy')[key]
    end

    proxy_with_empty_values = { 'proxy_host' => 'my-proxy.mine', 'proxy_port' => '1111', 'proxy_user_prefix' => '', 'proxy_pass' => nil, 'proxy_session_prefix' => '-ss-' }
    video_proxy_with_empty_values= { 'ytdl_proxy_host' => 'my-video-proxy.mine', 'ytdl_proxy_user_prefix' => '', 'ytdl_proxy_pass' => nil }
    api_key.application_settings = { config: proxy_with_empty_values.merge(video_proxy_with_empty_values) }; api_key.save
    ApiKey.current = api_key
    PenderConfig.current = nil
    assert_nil Media.valid_proxy('proxy')
    assert_nil Media.valid_proxy('ytdl_proxy')
  end

  test 'should upload images to s3 and update media data' do
    urls = %w(
      https://opensource.globo.com/hacktoberfest/
      https://hacktoberfest.digitalocean.com/
    )
    urls.each do |url|
      id = Media.get_id(url)
      m = Media.new url: url
      data = m.as_json
      assert_match /#{Pender::Store.current.storage_path('medias')}\/#{id}\/author_picture.(jpg|png)/, data[:author_picture], "Can't get `author_picture` from url #{url}"
      assert_match /#{Pender::Store.current.storage_path('medias')}\/#{id}\/picture.(jpg|png)/, data[:picture], "Can't get `picture` from url #{url}"
    end
  end

  test 'should encode URLs on raw key' do
    Media.any_instance.stubs(:get_crowdtangle_id).returns('111')
    Media.stubs(:crowdtangle_request).with(:facebook, '111').returns({ result: { posts: [{"platformId": "111", "platform":"Facebook", "expanded":"https://www.facebook.com/people/á<80><99>á<80><84>á<80>ºá<80>¸á<80><91>á<80>®á<80>¸/100056594476400"}]}})
    url = 'https://www.facebook.com/voice.myanmarnewsmm/posts/148110680335452'
    m = Media.new url: url
    m.data = Media.minimal_data(m)
    m.get_crowdtangle_data(:facebook)
    assert_equal "https://www.facebook.com/people/%C3%A1%3C80%3E%3C99%3E%C3%A1%3C80%3E%3C84%3E%C3%A1%3C80%3E%C2%BA%C3%A1%3C80%3E%C2%B8%C3%A1%3C80%3E%3C91%3E%C3%A1%3C80%3E%C2%AE%C3%A1%3C80%3E%C2%B8/100056594476400", cleanup_data_encoding(m.data)['raw']['crowdtangle']['posts'].first['expanded']
    Media.unstub(:crowdtangle_request)
    Media.any_instance.unstub(:get_crowdtangle_id)
  end

  test 'should handle error when cannot encode URLs on raw key' do
    Media.any_instance.stubs(:get_crowdtangle_id).returns('111')
    encoded_url = "https://www.facebook.com/people/á<80><99>á<80><84>á<80>ºá<80>¸á<80><91>á<80>®á<80>¸/100056594476400"
    Media.stubs(:crowdtangle_request).with(:facebook, '111').returns({ result: { posts: [{"platformId":"111","platform":"Facebook", "expanded": encoded_url }]}})
    url = 'https://www.facebook.com/voice.myanmarnewsmm/posts/148110680335452'
    m = Media.new url: url
    m.data = Media.minimal_data(m)
    m.get_crowdtangle_data(:facebook)

    URI.stubs(:encode)
    URI.stubs(:encode).with(encoded_url).raises(StandardError)
    assert_equal encoded_url, m.cleanup_data_encoding(m.data)['raw']['crowdtangle']['posts'].first['expanded']
    Media.unstub(:crowdtangle_request)
    Media.any_instance.unstub(:get_crowdtangle_id)
    URI.unstub(:encode)
  end

  test 'should handle error with crowdtangle requests' do
    PenderAirbrake.stubs(:notify).once
    WebMock.enable!
    WebMock.stub_request(:any, /api.crowdtangle.com/).to_return(body: '["invalid_json" : 123]')
    assert_equal({}, Media.crowdtangle_request('facebook', '111111_222222'))
    WebMock.disable!
    PenderAirbrake.unstub(:notify)
  end

  test 'should get crowdtandgle id from data' do
    data = {
      facebook: { uuid: 'facebook_id' }.with_indifferent_access,
      instagram: { raw: { graphql: { shortcode_media: { id: '111111', owner: { id: '222222'}}}}}.with_indifferent_access
    }
    url = 'https://example.com'
    m = Media.new url: url

    m.stubs(:data).returns(data[:facebook])
    assert_equal 'facebook_id', m.get_crowdtangle_id(:facebook)
  end

  test 'should decode url' do
    url = 'https://example.com'
    URI.stubs(:decode).raises(Encoding::CompatibilityError)
    assert_equal url, Media.decoded_uri(url)
    URI.unstub(:decode)
  end

  test 'should not convert original url' do
    original_url = 'http://localhost/api/medias.js?=1&url=https%3A%2F%2Ftwitter.com%2Fsstirling%2Fstatus%2F1453505920865087499'
    assert_equal 'http://localhost/api/medias.html?=1&url=https%3A%2F%2Ftwitter.com%2Fsstirling%2Fstatus%2F1453505920865087499', convert_url_to_format(original_url, 'html')
    assert_equal 'http://localhost/api/medias.js?=1&url=https%3A%2F%2Ftwitter.com%2Fsstirling%2Fstatus%2F1453505920865087499', original_url
  end

end
