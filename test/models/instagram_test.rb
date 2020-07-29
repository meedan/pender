require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class InstagramTest < ActiveSupport::TestCase
  test "should parse Instagram post" do
    m = create_media url: 'https://www.instagram.com/p/BJwkn34AqtN/'
    d = m.as_json
    assert_equal '@megadeth', d['username']
    assert_equal 'item', d['type']
    assert_match 'megadeth', d['author_name'].downcase
    assert_not_nil d['picture']
  end

  test "should parse Instagram profile" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML("<meta property='og:title' content='megadeth'><meta property='og:image' content='https://www.instagram.com/megadeth.png'>"))
    m = create_media url: 'https://www.instagram.com/megadeth'
    d = m.as_json
    assert_equal '@megadeth', d['username']
    assert_equal 'profile', d['type']
    assert_match 'megadeth', d['title']
    assert_match 'megadeth', d['author_name']
    assert_match /^http/, d['picture']
    Media.any_instance.unstub(:doc)
  end

  test "should get canonical URL parsed from html tags 2" do
    media1 = create_media url: 'https://www.instagram.com/p/CAdW7PMlTWc/?taken-by=kikoloureiro'
    media2 = create_media url: 'https://www.instagram.com/p/CAdW7PMlTWc'
    assert_match /https:\/\/www.instagram.com\/p\/CAdW7PMlTWc/, media1.url
    assert_match /https:\/\/www.instagram.com\/p\/CAdW7PMlTWc/, media2.url
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
    assert_equal 'megadeth', data[:author_name].downcase
    assert !data[:published_at].blank?
  end

  test "should store oembed data of a instagram post" do
    m = create_media url: 'https://www.instagram.com/p/CBJDglTpFUT/'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_match 'theintercept', data['raw']['oembed']['author_name']
    assert_match /It was a week/, data['raw']['oembed']['title']
  end

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

  test "should parse IGTV link as item" do
    m = create_media url: 'https://www.instagram.com/tv/B47W-ZVJpBv/?igshid=l5tx0fnl421e'
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal '@biakicis', d['username']
    assert_match /kicis/, d['author_name'].downcase
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

  test "should raise error if api redirects to login page" do
    m = create_media url: 'https://www.instagram.com/p/CAOdQ2Hha4k/'
    id = 'CAOdQ2Hha4k'
    api_url = "https://api.instagram.com/oembed/?url=http://instagr.am/p/#{id}"
    api_uri = URI.parse api_url
    http1 = 'mock';http1.stubs(:use_ssl=)
    Net::HTTP.stubs(:new).with(api_uri.host, api_uri.port).returns(http1)
    response_api = 'mock';response_api.stubs(:code).returns('301');response_api.stubs(:header).returns({'location' => 'https://www.instagram.com/accounts/login'})
    http1.stubs(:request).returns(response_api)
    error = assert_raise StandardError do
      m.get_instagram_json_data(api_url)
    end
    assert_equal 'Login required', error.message

    Net::HTTP.unstub(:new)
  end

  test "should parse redirected page when requesting api" do
    m = create_media url: 'https://www.instagram.com/p/CAOdQ2Hha4k/'
    id = 'CAOdQ2Hha4k'
    api_url = "https://api.instagram.com/oembed/?url=http://instagr.am/p/#{id}"
    api_uri = URI.parse api_url
    http1 = 'mock';http1.stubs(:use_ssl=)
    Net::HTTP.stubs(:new).with(api_uri.host, api_uri.port).returns(http1)
    response_api = 'mock';response_api.stubs(:code).returns('301');response_api.stubs(:header).returns({'location' => 'https://www.instagram.com/redirection'})
    http1.stubs(:request).returns(response_api)

    redirected_uri = URI.parse 'https://www.instagram.com/redirection'
    http2 = 'mock';http2.stubs(:use_ssl=)
    Net::HTTP.stubs(:new).with(redirected_uri.host, redirected_uri.port).returns(http2)
    response_api2 = 'mock';response_api2.stubs(:code).returns('200');response_api2.stubs(:body).returns("{\"username\":\"megadeth\"}")
    http2.stubs(:request).returns(response_api2)

    assert_nothing_raised do
      data = m.get_instagram_json_data(api_url)
      assert_equal 'megadeth', data['username']
    end

    Net::HTTP.unstub(:new)
  end

end 
