require 'test_helper'

class InstagramItemIntegrationTest < ActiveSupport::TestCase
  test "should parse Instagram item link for real" do
    m = Media.new url: 'https://www.instagram.com/p/CdOk-lLKmyH/'
    data = m.as_json
    assert_equal 'item', data['type']
    assert_equal 'CdOk-lLKmyH', data['external_id']
    assert !data['title'].blank?
  end

  test "should get canonical URL parsed from html tags" do
    media1 = create_media url: 'https://www.instagram.com/p/CAdW7PMlTWc/?taken-by=kikoloureiro'
    assert_match /https:\/\/www.instagram.com\/p\/CAdW7PMlTWc/, media1.url
  end
end

class InstagramItemUnitTest < ActiveSupport::TestCase
  INSTAGRAM_ITEM_API_REGEX = /instagram.com\/p\//

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
  end

  test "should set profile defaults to URL upon error" do
    WebMock.stub_request(:any, INSTAGRAM_ITEM_API_REGEX).to_raise(Net::ReadTimeout.new("Raised in test"))

    data = Parser::InstagramItem.new('https://www.instagram.com/p/fake-post').parse_data(nil)

    assert_equal 'fake-post', data['external_id']
    assert_match 'https://www.instagram.com/p/fake-post', data['description']
  end

  test "should attempt to set defaults from metatags on failure" do
    WebMock.stub_request(:any, INSTAGRAM_ITEM_API_REGEX).to_return(body: '', status: 401)

    doc = Nokogiri::HTML(<<~HTML)
      <meta name="twitter:site" content="@instagram">
      <meta name="twitter:image" content="https://example.com/1111">
      <meta name="twitter:title" content="Ana C. Lana (@direitatemrazao) • Instagram photos and videos">
      <meta name="description" content='Ana C. Lana shared a post on Instagram: \"Nada que a gente já não tenha vivido.\" Follow their account to see 541 posts.'>
      <meta property="og:site_name" content="Instagram">
      <meta property="og:title" content='Ana C. Lana on Instagram: \"Nada que a gente \n\njá não tenha vivido.\"'>
      <meta property="og:image" content="https://example.com/2222">
      <meta property="og:url" content="https://www.instagram.com/p/CjG7HTOLvd8/">
      <meta property="og:description" content='Ana C. Lana shared a post on Instagram: \"Nada que a gente já não tenha vivido.\" Follow their account to see 541 posts.'>
    HTML

    data = Parser::InstagramItem.new('https://www.instagram.com/p/fake-post').parse_data(doc)
    assert_equal "Nada que a gente \n\njá não tenha vivido.", data['title']
    assert_equal "@direitatemrazao", data['username']
    assert_equal "Nada que a gente \n\njá não tenha vivido.", data['description']
    assert_equal "https://example.com/2222", data['picture']
    assert_equal "Ana C. Lana", data['author_name']
    assert_equal "https://instagram.com/direitatemrazao", data['author_url']
    assert data['author_picture'].blank?
    assert data['published_at'].blank?
  end

  test "should return error on item data when link can't be found" do
    WebMock.stub_request(:any, INSTAGRAM_ITEM_API_REGEX).to_return(status: 404)

    data = {}
    airbrake_call_count = 0
    arguments_checker = Proc.new do |e|
      airbrake_call_count += 1
      assert_equal ProviderInstagram::ApiError, e.class
    end

    PenderAirbrake.stub(:notify, arguments_checker) do
      data = Parser::InstagramItem.new('https://www.instagram.com/p/fake-post').parse_data(doc)
      assert_equal 1, airbrake_call_count
    end
    assert_match /ProviderInstagram::ApiResponseCodeError/, data['error']['message']
  end

  test "should re-raise a wrapped error when parsing fails" do
    WebMock.stub_request(:any, INSTAGRAM_ITEM_API_REGEX).to_return(body: 'asdf', status: 200)

    data = {}
    airbrake_call_count = 0
    arguments_checker = Proc.new do |e|
      airbrake_call_count += 1
      assert_equal ProviderInstagram::ApiError, e.class
    end
    PenderAirbrake.stub(:notify, arguments_checker) do
      data = Parser::InstagramItem.new('https://www.instagram.com/p/fake-post').parse_data(doc)
      assert_equal 1, airbrake_call_count
    end
    assert_match /ProviderInstagram::ApiError/, data['error']['message']
  end

  test "should re-raise a wrapped error when redirected to a page that requires authentication" do
    WebMock.stub_request(:any, INSTAGRAM_ITEM_API_REGEX).to_return(body: '', status: 302, headers: { location: 'https://www.instagram.com/accounts/login/' })

    data = {}
    airbrake_call_count = 0
    arguments_checker = Proc.new do |e|
      airbrake_call_count += 1
      assert_equal ProviderInstagram::ApiError, e.class
    end
    PenderAirbrake.stub(:notify, arguments_checker) do
      data = Parser::InstagramItem.new('https://www.instagram.com/p/fake-post').parse_data(doc)
      assert_equal 1, airbrake_call_count
    end
    assert_match /ProviderInstagram::ApiAuthenticationError/, data['error']['message']
  end

  test 'should set item fields from successful api response' do
    WebMock.stub_request(:any, INSTAGRAM_ITEM_API_REGEX).to_return(body: graphql, status: 200)
    
    data = Parser::InstagramItem.new('https://www.instagram.com/p/fake-post').parse_data(doc)
    assert_equal 'fake-post', data['external_id']
    assert_equal '@retrobayarea', data['username']
    assert_match /This cool neon sign was located at the intersection of South Murphy and El Camino Real/, data['description']
    assert_match /This cool neon sign was located at the intersection of South Murphy and El Camino Real/, data['title']
    assert_match /scontent-sjc3-1.cdninstagram.com\/v\/t51.2885-15\/300827385_771443254176686_3645633281116479321_n.jpg/, data['picture']
    assert_equal 'Retro Bay Area', data['author_name']
    assert_equal 'https://instagram.com/retrobayarea', data['author_url']
    assert_match /scontent-sjc3-1.cdninstagram.com\/v\/t51.2885-19\/275782436_803363541058120_8527469417809134606_n.jpg/, data['author_picture']
    assert_equal Time.new(2022,8,23,16,51,41), data['published_at']
  end  

  test "should preserve all raw data, without overwriting" do
    WebMock.stub_request(:any, INSTAGRAM_ITEM_API_REGEX).to_return(body: graphql, status: 200)
    
    data = Parser::InstagramItem.new('https://www.instagram.com/p/fake-post').parse_data(doc)
    assert data['raw']['metatags'].present?
    assert data['raw']['api'].present?
  end
end
