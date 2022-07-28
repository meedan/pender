require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class InstagramTest < ActiveSupport::TestCase
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
    graphql_response = {
      'graphql' => {
        'user' => {
          'profile_pic_url' => 'https://instagram.net/v/29_n.jpg',
          'username' => 'c.afpfact',
          'full_name' => 'AFP Fact Check' 
        },
        'image_versions2' => {
          'candidates' => [
            { 'url' => 'https://instagram.net/v/28_n.jpg' } 
          ],
        },
        'caption' => {
          'text' => 'Verify misinformation on WhatsApp'
        }
      }
    }
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

  test "should parse Instagram link for real" do
    url = 'https://www.instagram.com/p/CdOk-lLKmyH/'
    m = Media.new url: url
    data = m.as_json
    assert_equal 'item', data['type']
    assert_equal '@ironmaiden', data['username']
    assert_match 'Iron Maiden', data['author_name']
    assert_match 'When and where was your last Maiden show?', data['title']
    assert_equal 'https://instagram.com/ironmaiden', data['author_url']
  end
end 
