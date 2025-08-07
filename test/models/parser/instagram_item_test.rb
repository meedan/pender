require 'test_helper'

class InstagramItemUnitTest < ActiveSupport::TestCase
  INSTAGRAM_ITEM_API_REGEX = /apify.com/

  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  def graphql
    @graphql ||= response_fixture_from_file('instagram-item-graphql.json')
  end

  def doc
    @doc ||= response_fixture_from_file('instagram-item-page.html', parse_as: :html)
  end

  test "returns provider and type" do
    assert_equal Parser::InstagramItem.type, 'instagram_item'
  end

  test "matches known URL patterns, and returns instance on success" do
    assert_nil Parser::InstagramItem.match?('https://example.com')
    assert_nil Parser::InstagramItem.match?('https://www.instagram.com/fake-account')
    
    match_one = Parser::InstagramItem.match?('https://www.instagram.com/p/CAdW7PMlTWc')
    assert_equal true, match_one.is_a?(Parser::InstagramItem)
    
    match_two = Parser::InstagramItem.match?('https://www.instagram.com/tv/CAdW7PMlTWc')
    assert_equal true, match_two.is_a?(Parser::InstagramItem)
    
    match_three = Parser::InstagramItem.match?('https://www.instagram.com/reel/CAdW7PMlTWc')
    assert_equal true, match_three.is_a?(Parser::InstagramItem)
    
    match_four = Parser::InstagramItem.match?('https://www.instagram.com/')
    assert_equal true, match_four.is_a?(Parser::InstagramItem)
  end

  test "should set profile defaults to URL upon error" do
    WebMock.stub_request(:post, INSTAGRAM_ITEM_API_REGEX).to_raise(Net::ReadTimeout.new("Raised in test"))

    data = Parser::InstagramItem.new('https://www.instagram.com/p/fake-post').parse_data(nil)

    assert_equal 'fake-post', data['external_id']
    assert_match 'https://www.instagram.com/p/fake-post', data['description']
  end

  test "should attempt to set defaults from metatags on failure" do
    WebMock.stub_request(:post, INSTAGRAM_ITEM_API_REGEX).to_return(status: 401)
  
    doc = Nokogiri::HTML(<<~HTML)
      <meta name="twitter:title" content="Ana C. Lana (@direitatemrazao) • Instagram photos and videos">
      <meta property="og:title" content='Ana C. Lana on Instagram: "Nada que a gente \n\njá não tenha vivido."'/>
      <meta property="og:image" content="https://example.com/2222">
    HTML
  
    data = Parser::InstagramItem.new('https://www.instagram.com/p/fake-post').parse_data(doc)
  
    assert_equal "Ana C. Lana on Instagram: \"Nada que a gente \n\njá não tenha vivido.\"", data['title']
    assert_equal "@direitatemrazao", data['username']
    assert_equal "Ana C. Lana on Instagram: \"Nada que a gente \n\njá não tenha vivido.\"", data['description']
    assert_equal "https://example.com/2222", data['picture']
    assert_equal "Ana", data['author_name']
    assert_equal "https://instagram.com/@direitatemrazao", data['author_url']
  end

  test "should re-raise a wrapped error when parsing fails" do
    WebMock.stub_request(:post, INSTAGRAM_ITEM_API_REGEX).to_return(body: 'asdf', status: 200)
  
    data = {}
    sentry_call_count = 0
    arguments_checker = Proc.new do |e|
      sentry_call_count += 1
      assert_equal MediaApifyItem::ApifyError, e.class
    end
    PenderSentry.stub(:notify, arguments_checker) do
      data = Parser::InstagramItem.new('https://www.instagram.com/p/fake-post').parse_data(doc)
      assert_equal 1, sentry_call_count
    end
    assert_match /Apify data not found or link is inaccessible/, data['error']['message']
  end

  test "should re-raise a wrapped error when redirected to a page that requires authentication" do
    WebMock.stub_request(:post, INSTAGRAM_ITEM_API_REGEX).to_return(status: 302, headers: { location: 'https://www.instagram.com/accounts/login/' })
  
    data = {}
    sentry_call_count = 0
    arguments_checker = Proc.new do |e|
      sentry_call_count += 1
      assert_equal MediaApifyItem::ApifyError, e.class
    end
    PenderSentry.stub(:notify, arguments_checker) do
      data = Parser::InstagramItem.new('https://www.instagram.com/p/fake-post').parse_data(doc)
      assert_equal 1, sentry_call_count
    end
    assert_match /Apify data not found or link is inaccessible/, data['error']['message']
  end

  test 'should set item fields from successful Apify response' do
    WebMock.stub_request(:post, INSTAGRAM_ITEM_API_REGEX)
           .to_return(body: '[{"inputUrl": "https://www.instagram.com/p/fake-post", "id": "fake-post", "caption": "This cool caption", "ownerUsername": "retrobayarea", "displayUrl": "https://example.com/image.jpg", "ownerFullName": "Retro Bay Area", "timestamp": "2024-08-21T17:27:17.000Z"}]', status: 200)

    data = Parser::InstagramItem.new('https://www.instagram.com/p/fake-post').parse_data(doc)
    assert_equal 'fake-post', data['external_id']
    assert_equal '@retrobayarea', data['username']
    assert_equal "This cool caption", data['description']
    assert_equal "This cool caption", data['title']
    assert_equal "https://example.com/image.jpg", data['picture']
    assert_equal "Retro Bay Area", data['author_name']
    assert_equal "https://instagram.com/retrobayarea", data['author_url']
    assert_equal Time.parse("2024-08-21T17:27:17.000Z"), data['published_at']
  end  

  test "should preserve all raw data, without overwriting" do
    WebMock.stub_request(:post, INSTAGRAM_ITEM_API_REGEX)
           .to_return(body: '[{"inputUrl": "https://www.instagram.com/p/fake-post", "id": "fake-post", "caption": "Test caption", "displayUrl": "https://example.com/image.jpg"}]', status: 200)
    
    data = Parser::InstagramItem.new('https://www.instagram.com/p/fake-post').parse_data(doc)
    assert data['raw']['metatags'].present?
    assert data['raw']['apify'].present?
  end

  test "should return url as title when redirected to instagram main page" do
    url = 'https://www.instagram.com/p/CdOk-lLKmyH/'
    instagram_main_page = 'https://instagram.com/'
    
    WebMock.stub_request(:get, url).to_return(status: 302, headers: { 'location' => instagram_main_page })
    WebMock.stub_request(:get, instagram_main_page).to_return(status: 200, body: '<html>Instagram</html>')
    WebMock.stub_request(:post, /apify.com/).to_return(status: 200)

    media = Media.new(url: url)
    data = media.process_and_return_json

    assert_equal 'https://www.instagram.com/p/CdOk-lLKmyH', data['title']
    assert_equal 'instagram', data['provider']
    assert_equal 'item', data['type']
  end
end
