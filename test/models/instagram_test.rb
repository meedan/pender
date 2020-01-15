require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class InstagramTest < ActiveSupport::TestCase
  test "should parse Instagram link" do
    m = create_media url: 'https://www.instagram.com/p/BJwkn34AqtN/'
    d = m.as_json
    assert_equal '@megadeth', d['username']
    assert_equal 'item', d['type']
    assert_equal 'Megadeth', d['author_name']
    assert_not_nil d['picture']
  end

  test "should parse Instagram profile" do
    m = create_media url: 'https://www.instagram.com/megadeth'
    d = m.as_json
    assert_equal '@megadeth', d['username']
    assert_equal 'profile', d['type']
    assert_equal 'megadeth', d['title']
    assert_equal 'megadeth', d['author_name']
    assert_match /^http/, d['picture']
  end

  test "should get canonical URL parsed from html tags 2" do
    media1 = create_media url: 'https://www.instagram.com/p/BK4YliEAatH/?taken-by=anxiaostudio'
    media2 = create_media url: 'https://www.instagram.com/p/BK4YliEAatH/'
    assert_equal 'https://www.instagram.com/p/BK4YliEAatH?taken-by=anxiaostudio', media1.url
    assert_equal 'https://www.instagram.com/p/BK4YliEAatH', media2.url
  end

  test "should return Instagram author picture" do
    m = create_media url: 'https://www.instagram.com/p/BOXV2-7BPAu'
    d = m.as_json
    assert_match /^http/, d['author_picture']
  end

  test "should parse Instagram post from page and get username and name" do
    m = create_media url: 'https://www.instagram.com/p/BJwkn34AqtN/'
    d = m.as_json
    assert_equal '@megadeth', d['username']
    assert_equal 'Megadeth', d['author_name']
  end

  test "should store data of post returned by instagram api and graphql" do
    m = create_media url: 'https://www.instagram.com/p/BJwkn34AqtN/'
    data = m.as_json
    assert data['raw']['api'].is_a? Hash
    assert !data['raw']['api'].empty?

    assert data['raw']['graphql'].is_a? Hash
    assert !data['raw']['graphql'].empty?

    assert_equal '@megadeth', data[:username]
    assert_match /Peace Sells/, data[:description]
    assert_match /Peace Sells/, data[:title]
    assert !data[:picture].blank?
    assert_equal "https://www.instagram.com/megadeth", data[:author_url]
    assert !data[:html].blank?
    assert !data[:author_picture].blank?
    assert_equal 'Megadeth', data[:author_name]
    assert !data[:published_at].blank?
  end

  test "should store oembed data of a instagram post" do
    m = create_media url: 'https://www.instagram.com/p/BJwkn34AqtN/'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal 'megadeth', data['raw']['oembed']['author_name']
    assert_match /Peace Sells/, data['raw']['oembed']['title']
  end

  test "should use username as author_name on Instagram profile when a full name is not available" do
    m = create_media url: 'https://www.instagram.com/emeliiejanssonn/'
    data = m.as_json
    assert_equal 'emeliiejanssonn', data['author_name']
  end

  test "should not have the subkey json+ld if the tag is not present on page" do
    m = create_media url: 'https://www.instagram.com/emeliiejanssonn/'
    data = m.as_json
    assert data['raw']['json+ld'].nil?
  end

  test "should have external id for post" do
    m = create_media url: 'https://www.instagram.com/p/BxxBzJmiR00/'
    data = m.as_json
    assert_equal 'BxxBzJmiR00', data['external_id']
  end

  test "should have external id for profile" do
    m = create_media url: 'https://www.instagram.com/ironmaiden/'
    data = m.as_json
    assert_equal 'ironmaiden', data['external_id']
  end

  test "should parse IGTV link as item" do
    m = create_media url: 'https://www.instagram.com/tv/B47W-ZVJpBv/?igshid=l5tx0fnl421e'
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal '@biakicis', d['username']
    assert_equal 'Bia Kicis', d['author_name']
  end

  test "should return error on data when can't get info from api and graphql" do
    id = 'B6_wqMHgQ12'
    Media.any_instance.stubs(:get_instagram_json_data).raises('Net::HTTPNotFound: Not Found')
    m = create_media url: "https://www.instagram.com/p/#{id}/"
    d = m.as_json
    assert_equal id, d['external_id']
    assert_equal 'item', d['type']
    assert_equal '', d['username']
    assert_equal '', d['author_name']
    assert_match /Not Found/, d['raw']['api']['error']['message']
    assert_match /Not Found/, d['raw']['graphql']['error']['message']
    Media.any_instance.unstub(:get_instagram_json_data)
  end

  test "should parse when only graphql returns data" do
    m = create_media url: 'https://www.instagram.com/p/B6_wqMHgQ12/'
    id = 'B6_wqMHgQ12'
    Media.any_instance.stubs(:get_instagram_json_data).with("https://api.instagram.com/oembed/?url=http://instagr.am/p/#{id}").raises('Net::HTTPNotFound: Not Found')
    graphql_response = { 'graphql' => {
      "shortcode_media"=>{"display_url"=>"https://instagram.net/v/29_n.jpg",
      "edge_media_to_caption"=>{"edges"=>[{"node"=>{"text"=>"Verify misinformation on WhatsApp"}}]},
      "owner"=>{"profile_pic_url"=>"https://instagram.net/v/56_n.jpg", "username"=>"c.afpfact", "full_name"=>"AFP Fact Check"}}}}
    Media.any_instance.stubs(:get_instagram_json_data).with("https://www.instagram.com/p/#{id}/?__a=1").returns(graphql_response)
    d = m.as_json
    assert_equal 'B6_wqMHgQ12', d['external_id']
    assert_equal 'item', d['type']
    assert_equal '@c.afpfact', d['username']
    assert_equal 'AFP Fact Check', d['author_name']
    assert_equal 'Verify misinformation on WhatsApp', d['title']
    assert_equal 'https://instagram.net/v/29_n.jpg', d['picture']
    assert_equal 'https://instagram.net/v/56_n.jpg', d['author_picture']
    Media.any_instance.unstub(:get_instagram_json_data)
  end

end 
