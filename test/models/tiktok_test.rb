require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class TiktokIntegrationTest < ActiveSupport::TestCase
  test "should parse Tiktok profile for real" do
    m = create_media url: 'https://www.tiktok.com/@scout2015'
    data = m.as_json
    assert_equal '@scout2015', data['username']
    assert_equal 'profile', data['type']
    assert_equal 'tiktok', data['provider']
    assert !data['title'].blank?
    assert !data['author_name'].blank?
    assert_equal '@scout2015', data['external_id']
    assert_match 'https://www.tiktok.com/@scout2015', m.url
    assert_nil data['error']
  end

  test "should parse Tiktok item for real" do
    m = create_media url: 'https://www.tiktok.com/@scout2015/video/6771039287917038854'
    data = m.as_json
    assert_equal 'item', data['type']
    assert_match /Who agrees/, data['title']
    assert_match /Scout.+Suki/, data['author_name']
    assert_equal '6771039287917038854', data['external_id']
    assert_match 'https://www.tiktok.com/@scout2015', data['author_url']
    assert_match /^http/, data['picture']
    assert_nil data['error']
    assert_equal '@scout2015', data['username']
  end

  test "should parse Tiktok link 2" do
    m = create_media url: 'https://www.tiktok.com/@scout2015/video/7094001694408756526?is_from_webapp=1&sender_device=pc&web_id=7064890017416234497'
    data = m.as_json
    assert_equal 'item', data['type']
    assert_match /Should we keep/, data['title']
    assert_match /Scout.+Suki/, data['author_name']
    assert_equal '7094001694408756526', data['external_id']
    assert_match 'https://www.tiktok.com/@scout2015', data['author_url']
    assert_match /^http/, data['picture']
    assert_nil data['error']
    assert_equal '@scout2015', data['username']
  end

  test "should parse short TikTok link" do
    m = create_media url: 'https://vt.tiktok.com/ZSduCHt6g/?k=1'
    data = m.as_json
    assert_equal 'item', data['type']
    assert_match /Sabotage/, data['title']
    assert_match /Michael/, data['author_name']
    assert_equal '7090122043793984795', data['external_id']
    assert_match 'https://www.tiktok.com/@ken28gallardo', data['author_url']
    assert_nil data['error']
    assert_equal '@ken28gallardo', data['username']
  end
end

class TikTokUnitTest < ActiveSupport::TestCase
  def setup
    WebMock.enable!
    WebMock.disable_net_connect!(allow_localhost: true, allow: [/minio/])
    WebMock.stub_request(:post, /safebrowsing.googleapis.com/).to_return(status: 200, body: { matches: [] }.to_json )
    WebMock.stub_request(:get, /graph.facebook.com/).to_return(status: 200, body: '' )
    WebMock.stub_request(:get, /tiktokcdn.com/).to_return(status: 200, body: '' )

    WebMock.stub_request(:any, /www.tiktok.com/).to_return(body: '', status: 200)
  end

  test "should parse Tiktok profile with proxy if title is the site name" do
    blank_page = '<html><head><title>TikTok</title></head><body></body></html>'
    page = '<html><head><title>Huxley the Panda Puppy</title><meta property="og:image" content="https://tiktokcdn.com/image.jpeg"><meta property="twitter:creator" content="Huxley the Panda Puppy"><meta property="og:description" content="Here to make ur day"></head><body></body></html>'
    url = 'https://www.tiktok.com/@huxleythepandapuppy'
    header_options = Media.send(:html_options, url)
    Media.any_instance.stubs(:get_html).with(header_options, true).returns(Nokogiri::HTML(page))
    Media.any_instance.stubs(:get_html).with(header_options, false).returns(Nokogiri::HTML(blank_page))
    Media.any_instance.stubs(:get_html).with(header_options).returns(Nokogiri::HTML(blank_page))
    m = create_media url: url
    data = m.as_json

    # Make sure to remove stubs before we do test assertions,
    # otherwise if the tests fail the stubs will remain for other tests
    Media.any_instance.unstub(:get_html)

    assert_equal '@huxleythepandapuppy', data['username']
    assert_equal 'profile', data['type']
    assert_equal 'tiktok', data['provider']
    assert_equal 'Huxley the Panda Puppy', data['title']
    assert_equal 'Huxley the Panda Puppy', data['author_name']
    assert_equal '@huxleythepandapuppy', data['external_id']
    assert_match 'https://assets.path/medias/', data['picture']
    assert_match 'https://www.tiktok.com/@huxleythepandapuppy', m.url
  end

  test "should set profile defaults upon error" do
    m = create_media url: 'https://www.tiktok.com/@fakeaccount'
    data = m.as_json
    assert_equal '@fakeaccount', data['external_id']
    assert_equal '@fakeaccount', data['username']
    assert_equal 'profile', data['type']
    assert_match '@fakeaccount', data['title']
    assert_match 'https://www.tiktok.com/@fakeaccount', data['description']
  end

  test "should set item defaults upon error" do
    m = create_media url: 'https://www.tiktok.com/user/video/abcdef/?k=1'
    data = m.as_json
    assert_equal 'item', data['type']
    assert_match 'https://www.tiktok.com/user/video/abcdef', data['title']
    assert_match 'https://www.tiktok.com/user/video/abcdef', data['description']
  end
end
