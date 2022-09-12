require 'test_helper'

class TiktokItemIntegrationTest < ActiveSupport::TestCase
  test "should parse Tiktok item for real" do
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

class TiktokItemUnitTest < ActiveSupport::TestCase
  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  def oembed
    @oembed ||= response_fixture_from_file('tiktok-item-oembed.json')
  end

  def doc
    @doc ||= response_fixture_from_file('tiktok-item-page.html', parse_as: :html)
  end

  test "returns provider and type" do
    assert_equal Parser::TiktokItem.type, 'tiktok_item'
  end

  test "matches known URL patterns, and returns instance on success" do
    assert_nil Parser::TiktokItem.match?('https://example.com')
    assert_nil = Parser::TiktokItem.match?('https://www.tiktok.com/@fakeaccount')
    
    match_one = Parser::TiktokItem.match?('https://www.tiktok.com/@fakeaccount/video/abcdef?a=1')
    assert_equal true, match_one.is_a?(Parser::TiktokItem)
  end

  test "should set profile defaults upon error" do
    WebMock.stub_request(:any, /tiktok.com\/oembed\?url=/).to_raise(Net::ReadTimeout.new("Raised in test"))

    data = Parser::TiktokItem.new('https://www.tiktok.com/@fakeaccount/video/abcdef').parse_data(doc)

    assert_match 'https://www.tiktok.com/@fakeaccount/video/abcdef', data['description']
  end

  test "assigns values to hash from the HTML doc" do
    WebMock.stub_request(:any, /tiktok.com\/oembed\?url=/).to_return(status: 200, body: oembed)

    data = Parser::TiktokItem.new('https://www.tiktok.com/@fakeaccount/video/abcdef').parse_data(doc)

    assert_equal '@fakeaccount', data['username']
    assert_equal 'abcdef', data['external_id']
    assert_match "I've had this corn interview stuck in my head for days 😂🌽🌽🌽🌽", data['description']
    assert_match "I've had this corn interview stuck in my head for days 😂🌽🌽🌽🌽", data['title']
    assert_match "https://p19-sign.tiktokcdn-us.com/obj/useast5/fake-image", data['picture']
    assert_match "https://www.tiktok.com/@rebelunicorncrafts", data['author_url']
    assert_not_nil data['html']
    assert_equal "Lacey - Curious Watercolor&Art", data['author_name']
  end

  test "stores the raw response data under oembed & api keys" do
    WebMock.stub_request(:any, /tiktok.com\/oembed\?url=/).to_return(status: 200, body: oembed)

    data = Parser::TiktokItem.new('https://www.tiktok.com/@fakeaccount/video/abcdef').parse_data(doc)

    assert_not_nil data['raw']['oembed']
    assert_not_nil data['raw']['api']
  end
end
