require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class InstagramTest < ActiveSupport::TestCase
  # TODO Must be fixed on #8794
  #test "should parse Instagram post" do
  #  m = create_media url: 'https://www.instagram.com/p/BJwkn34AqtN/'
  #  data = m.as_json
  #  assert_equal '@megadeth',data['username']
  #  assert_equal 'item',data['type']
  #  assert_match 'megadeth',data['author_name'].downcase
  #  assert_not_nil data['picture']
  #end

  test "should parse Instagram profile" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML("<meta property='og:title' content='megadeth'><meta property='og:image' content='https://www.instagram.com/megadeth.png'>"))
    m = create_media url: 'https://www.instagram.com/megadeth'
    data = m.as_json
    assert_equal '@megadeth',data['username']
    assert_equal 'profile',data['type']
    assert_match 'megadeth',data['title']
    assert_match 'megadeth',data['author_name']
    assert_match /^http/,data['picture']
    Media.any_instance.unstub(:doc)
  end

  test "should get canonical URL parsed from html tags 2" do
    media1 = create_media url: 'https://www.instagram.com/p/CAdW7PMlTWc/?taken-by=kikoloureiro'
    media2 = create_media url: 'https://www.instagram.com/p/CAdW7PMlTWc'
    assert_match /https:\/\/www.instagram.com\/p\/CAdW7PMlTWc/, media1.url
    assert_match /https:\/\/www.instagram.com\/p\/CAdW7PMlTWc/, media2.url
  end

  # TODO Must be fixed on #8794
  #test "should store data of post returned by instagram crowdtangle api and graphql" do
  #  m = create_media url: 'https://www.instagram.com/p/BJwkn34AqtN/'
  #  data = m.as_json
  #  assert data['raw']['crowdtangle'].is_a? Hash
  #  assert !data['raw']['crowdtangle'].empty?
  #  assert data['raw']['graphql'].is_a? Hash
  #  assert !data['raw']['graphql'].empty?

  #  assert_equal '@megadeth', data[:username]
  #  assert_match /Peace Sells/, data[:description]
  #  assert_match /Peace Sells/, data[:title]
  #  assert !data[:picture].blank?
  #  assert_match /https:\/\/www.instagram.com\/megadeth/, data[:author_url]
  #  # TODO Generate Instagram html (related: #8761)
  #  #assert !data[:html].blank?
  #  assert_equal 'megadeth', data[:author_name].downcase
  #  assert !data[:published_at].blank?
  #end

  # TODO Must be fixed on #8794
  #test "should store crowdtangle data of a instagram post" do
  #  m = create_media url: 'https://www.instagram.com/p/CBJDglTpFUT/'
  #  data = m.as_json

  #  assert data['raw']['crowdtangle'].is_a? Hash
  #  post_info = data['raw']['crowdtangle']['posts'].first
  #  assert_match 'theintercept', post_info['account']['handle']
  #  assert_match 'The Intercept', post_info['account']['name']
  #  assert_match /It was a week/, post_info['description']
  #end

  test "should use username as author_name on Instagram profile when a full name is not available" do
    Media.any_instance.stubs(:get_instagram_author_name).returns(nil)
    m = create_media url: 'https://www.instagram.com/emeliiejanssonn/'
    data = m.as_json
    assert_match 'emeliiejanssonn', data['author_name']
    Media.any_instance.unstub(:get_instagram_author_name)
  end

  test "should not have the subkey json+ld if the tag is not present on page" do
    m = create_media url: 'https://www.instagram.com/emeliiejanssonn/'
    data = m.as_json
    assert data['raw']['json+ld'].nil?
  end

  test "should have external id for post" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML("<meta property='og:url' content='https://www.instagram.com/p/BxxBzJmiR00/'>"))
    m = create_media url: 'https://www.instagram.com/p/BxxBzJmiR00/'
    data = m.as_json
    assert_equal 'BxxBzJmiR00', data['external_id']
    Media.any_instance.unstub(:doc)
  end

  test "should have external id for profile" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML("<meta property='og:url' content='https://www.instagram.com/ironmaiden/'>"))
    m = create_media url: 'https://www.instagram.com/ironmaiden/'
    data = m.as_json
    assert_equal 'ironmaiden', data['external_id']
    Media.any_instance.unstub(:doc)
  end

  # TODO Must be fixed on #8794
  #test "should parse IGTV link as item" do
  #  m = create_media url: 'https://www.instagram.com/tv/B47W-ZVJpBv/?igshid=l5tx0fnl421e'
  #  data = m.as_json
  #  assert_equal 'item', data['type']
  #  assert_equal '@biakicis', data['username']
  #  assert_match /kicis/, data['author_name'].downcase
  #end

  test "should return error on data when can't get info from graphql" do
    id = 'B6_wqMHgQ12'
    Media.any_instance.stubs(:get_instagram_graphql_data).raises('Net::HTTPNotFound: Not Found')
    m = create_media url: "https://www.instagram.com/p/#{id}/"
    data = m.as_json
    assert_equal id, data['external_id']
    assert_equal 'item', data['type']
    assert_equal '', data['username']
    assert_equal '', data['author_name']
    assert_match /Not Found/, data['raw']['graphql']['error']['message']
    Media.any_instance.unstub(:get_instagram_graphql_data)
  end

  # TODO Must be fixed on #8794
  #test "should parse when only graphql returns data" do
  #  m = create_media url: 'https://www.instagram.com/p/B6_wqMHgQ12/'
  #  id = 'B6_wqMHgQ12'
  #  Media.any_instance.stubs(:get_instagram_json_data).with("https://api.instagram.com/oembed/?url=http://instagr.am/p/#{id}").raises('Net::HTTPNotFound: Not Found')
  #  graphql_response = { 'graphql' => {
  #    "shortcode_media"=>{"display_url"=>"https://instagram.net/v/29_n.jpg",
  #    "edge_media_to_caption"=>{"edges"=>[{"node"=>{"text"=>"Verify misinformation on WhatsApp"}}]},
  #    "owner"=>{"profile_pic_url"=>"https://instagram.net/v/56_n.jpg", "username"=>"c.afpfact", "full_name"=>"AFP Fact Check"}}}}
  #  Media.any_instance.stubs(:get_instagram_json_data).with("https://www.instagram.com/p/#{id}/?__a=1").returns(graphql_response)
  #  data = m.as_json
  #  assert_equal 'B6_wqMHgQ12',data['external_id']
  #  assert_equal 'item',data['type']
  #  assert_equal '@c.afpfact',data['username']
  #  assert_match 'AFP Fact Check',data['author_name']
  #  assert_match /misinformation/,data['title']
  #  assert_match /picture.jpg/,data['picture']
  #  assert_match /author_picture.jpg/,data['author_picture']
  #  Media.any_instance.unstub(:get_instagram_json_data)
  #end

  test "should not raise error notification when redirected to login page" do
    Media.stubs(:is_a_login_page).returns(true)
    PenderAirbrake.stubs(:notify).never
    m = create_media url: 'https://www.instagram.com/p/CFld5x6B6Bw/'
    data = m.as_json
    assert_equal 'CFld5x6B6Bw', data['external_id']
    assert_equal 'item', data['type']
    assert_equal '', data['username']
    assert_equal '', data['author_name']
    assert_equal '', data['html']
    assert_match /Login required/, data['raw']['graphql']['error']['message']
    Media.unstub(:is_a_login_page)
    PenderAirbrake.unstub(:notify)
  end
end 
