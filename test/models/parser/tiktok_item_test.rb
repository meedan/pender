require 'test_helper'

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

    match_one = Parser::TiktokItem.match?('https://www.tiktok.com/tag/randomtag')
    assert_equal true, match_one.is_a?(Parser::TiktokItem)
  end

  test "sets 'external_id' and 'username' as empty string for unmatched URL pattern" do
    WebMock.stub_request(:any, /tiktok.com\/oembed\?url=/).to_return(status: 200, body: oembed)
    
    data = Parser::TiktokItem.new('https://www.tiktok.com/abcdef').parse_data(doc)

    assert_equal '', data['external_id']
    assert_equal '', data['username']
  end

  test "adds 'Tag: ' to title when it matches TIKTOK_TAG_URL" do
    WebMock.stub_request(:any, /tiktok.com\/oembed\?url=/).to_return(status: 200, body: oembed)
    
    data = Parser::TiktokItem.new('https://www.tiktok.com/tag/abcdef').parse_data(doc)

    assert_match "Tag: abcdef", data['title']
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

    assert_equal JSON.parse(oembed), data['raw']['oembed']
    assert_equal JSON.parse(oembed), data['raw']['api']
  end

  test ".oembed_url returns oembed URL" do
    url = Parser::TiktokItem.new('https://tiktok.com/fakeaccount/1234').oembed_url
    assert_equal 'https://www.tiktok.com/oembed?url=https://tiktok.com/fakeaccount/1234', url
  end
end
