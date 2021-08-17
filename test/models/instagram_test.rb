require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class InstagramTest < ActiveSupport::TestCase
  test "should parse Instagram post" do
    post_id = '1328722959803788109_343260652'
    Media.any_instance.stubs(:get_crowdtangle_id).returns(post_id)
    data = {"result"=>{"posts"=>[{"platformId"=>post_id,"description"=>"Peace Sells✌💲#vicrattlehead #megadeth #dystopiaworldtour #mexicocity","account"=>{"id"=>529101, "name"=>"Megadeth", "handle"=>"megadeth"}}]}}
    Media.stubs(:crowdtangle_request).returns(data)
    m = create_media url: 'https://www.instagram.com/p/BJwkn34AqtN/'
    data = m.as_json
    assert data['raw']['crowdtangle'].is_a? Hash
    assert !data['raw']['crowdtangle'].empty?
    assert_equal '@megadeth',data['username']
    assert_equal 'item',data['type']
    assert_match 'megadeth',data['author_name'].downcase
    assert_match /Peace Sells/, data[:description]
    assert_match /Peace Sells/, data[:title]
    assert_not_nil data['picture']
    Media.unstub(:crowdtangle_request)
    Media.any_instance.unstub(:get_crowdtangle_id)
  end

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

  test "should store crowdtangle data of a instagram post" do
    Media.any_instance.stubs(:get_crowdtangle_id).returns('2326406115734344979_3076818846')
    m = create_media url: 'https://www.instagram.com/p/CBJDglTpFUT/'
    data = m.as_json

    assert data['raw']['crowdtangle'].is_a? Hash
    assert !data['raw']['crowdtangle'].empty?
    assert_equal 'item',data['type']
    post_info = data['raw']['crowdtangle']['posts'].first
    assert_match 'theintercept', post_info['account']['handle']
    assert_match 'The Intercept', post_info['account']['name']
    assert_match /It was a week/, post_info['description']
    Media.any_instance.unstub(:get_crowdtangle_id)
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
    post_id = '2178435889592963183_3651758'
    Media.any_instance.stubs(:get_crowdtangle_id).returns(post_id)
    data = {"result"=>{"posts"=>[{"platformId":post_id,"description"=>"Vejam que lindo o Lula sendo recebido com todo amor e carinho","account"=>{"id"=>6506893, "name"=>"Bia Kicis \u{1F9FF}", "handle"=>"biakicis"}}]}}
    Media.stubs(:crowdtangle_request).returns(data)
    m = create_media url: 'https://www.instagram.com/tv/B47W-ZVJpBv/?igshid=l5tx0fnl421e'
    data = m.as_json
    assert_equal 'item', data['type']
    assert_equal '@biakicis', data['username']
    assert_match /kicis/, data['author_name'].downcase
    Media.unstub(:crowdtangle_request)
    Media.any_instance.unstub(:get_crowdtangle_id)
  end

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

  test "should parse when only graphql returns data" do
    Media.stubs(:get_crowdtangle_data).with(:instagram).returns(nil)
    graphql_response = { 'graphql' => {
      "shortcode_media"=>{"display_url"=>"https://instagram.net/v/29_n.jpg",
      "edge_media_to_caption"=>{"edges"=>[{"node"=>{"text"=>"Verify misinformation on WhatsApp"}}]},
      "owner"=>{"profile_pic_url"=>"https://instagram.net/v/56_n.jpg", "username"=>"c.afpfact", "full_name"=>"AFP Fact Check"}}}}
    Media.any_instance.stubs(:get_instagram_graphql_data).returns(graphql_response['graphql'])
    m = create_media url: 'https://www.instagram.com/p/B6_wqMHgQ12/'
    data = m.as_json
    assert_equal 'B6_wqMHgQ12', data['external_id']
    assert_equal 'item', data['type']
    assert_equal '@c.afpfact', data['username']
    assert_match 'AFP Fact Check', data['author_name']
    assert_match /misinformation/, data['title']
    assert !data['picture'].blank?
    assert !data['author_picture'].blank?
    Media.unstub(:get_crowdtangle_data)
    Media.any_instance.unstub(:get_instagram_graphql_data)
  end

  test "should not raise error notification when redirected to login page" do
    PenderAirbrake.stubs(:notify).never
    id = 'CFld5x6B6Bw'
    m = create_media url: "https://www.instagram.com/p/#{id}/"
    WebMock.enable!
    WebMock.stub_request(:any, /instagram.com\/p\/#{id}\/\?__a=1/).to_return(body: '', headers: { location: 'https://www.instagram.com/accounts/login/' }, status: 302)

    data = m.as_json
    assert_equal 'CFld5x6B6Bw', data['external_id']
    assert_equal 'item', data['type']
    assert_equal '', data['html']
    assert_match /Login required/, data['raw']['graphql']['error']['message']
    PenderAirbrake.unstub(:notify)
    WebMock.disable!
  end
end 
