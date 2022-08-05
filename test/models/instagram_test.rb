require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class InstagramTest < ActiveSupport::TestCase
  INSTAGRAM_PROFILE_API_REGEX = /i.instagram.com\/api\/v1\/users\/web_profile_info\//
  INSTAGRAM_ITEM_API_REGEX = /instagram.com\/p\//

  test "should parse Instagram item link for real" do
    m = Media.new url: 'https://www.instagram.com/p/CdOk-lLKmyH/'
    data = m.as_json
    assert_equal 'item', data['type']
    assert_equal 'CdOk-lLKmyH', data['external_id']
    assert !data['description'].blank?
    assert !data['title'].blank?
  end

  test "should parse Instagram profile link for real" do
    m = Media.new url: 'https://www.instagram.com/ironmaiden'
    data = m.as_json
    assert_equal 'profile', data['type']
    assert_equal 'ironmaiden', data['external_id']
    assert_equal '@ironmaiden', data['username']
    assert_match 'ironmaiden', data['title']
    assert !data['description'].blank?
  end

  test "should get canonical URL parsed from html tags 2" do
    media1 = create_media url: 'https://www.instagram.com/p/CAdW7PMlTWc/?taken-by=kikoloureiro'
    media2 = create_media url: 'https://www.instagram.com/p/CAdW7PMlTWc'
    assert_match /https:\/\/www.instagram.com\/p\/CAdW7PMlTWc/, media1.url
    assert_match /https:\/\/www.instagram.com\/p\/CAdW7PMlTWc/, media2.url
  end

  test "should match different item url patterns" do
    post_1 = create_media(url: 'https://www.instagram.com/p/CAdW7PMlTWc').as_json
    post_2 = create_media(url: 'https://www.instagram.com/tv/CAdW7PMlTWc').as_json
    post_3 = create_media(url: 'https://www.instagram.com/reel/CAdW7PMlTWc').as_json

    assert_equal 'item', post_1['type']
    assert_equal 'instagram', post_1['provider']
    assert_equal 'item', post_2['type']
    assert_equal 'instagram', post_2['provider']
    assert_equal 'item', post_3['type']
    assert_equal 'instagram', post_3['provider']
  end

  test "should set profile defaults upon error" do
    WebMock.enable!
    WebMock.stub_request(:any, INSTAGRAM_PROFILE_API_REGEX).to_return(body: 'asdf', status: 200)

    m = create_media url: 'https://www.instagram.com/megadeth'
    data = m.as_json
    assert_equal 'megadeth', data['external_id']
    assert_equal '@megadeth', data['username']
    assert_equal 'profile', data['type']
    assert_match 'megadeth', data['title']
    assert_match 'https://www.instagram.com/megadeth', data['description']

    WebMock.disable!
  end

  test "should set item defaults upon error" do
    WebMock.enable!
    WebMock.stub_request(:any, INSTAGRAM_ITEM_API_REGEX).to_return(body: 'asdf', status: 200)

    url = 'https://www.instagram.com/p/B6_wqMHgQ12/'
    m = create_media url: url
    data = m.as_json
    assert_equal 'B6_wqMHgQ12', data['external_id']
    assert_equal 'item', data['type']
    assert_equal 'https://www.instagram.com/p/B6_wqMHgQ12', data['title']
    assert_equal 'https://www.instagram.com/p/B6_wqMHgQ12', data['description']

    WebMock.disable!
  end

  test "should return error on item data when link can't be found" do
    WebMock.enable!
    WebMock.stub_request(:any, INSTAGRAM_ITEM_API_REGEX).to_return(status: 404)

    m = create_media url: "https://www.instagram.com/p/asdflkasjdflasdkfj/"
    data = m.as_json
    assert_match /Net::HTTPNotFound/, data['error']['message']

    WebMock.disable!
  end

  test "should return error on profile data when link can't be found" do
    WebMock.enable!
    WebMock.stub_request(:any, INSTAGRAM_PROFILE_API_REGEX).to_return(status: 404)

    m = create_media url: "https://www.instagram.com/asdflkajsdflkajsdf/"
    data = m.as_json
    assert_match /Net::HTTPNotFound/, data['error']['message']

    WebMock.disable!
  end

  test "should re-raise a wrapped error when parsing fails" do
    WebMock.enable!
    WebMock.stub_request(:any, INSTAGRAM_PROFILE_API_REGEX).to_return(body: 'asdf', status: 200)

    airbrake_call_count = 0
    arguments_checker = Proc.new do |e|
      airbrake_call_count += 1
      assert_equal Instagram::ApiError, e.class
    end
    PenderAirbrake.stub(:notify, arguments_checker) do
      m = create_media url: "https://www.instagram.com/megadeth"
      data = m.as_json
      assert_equal 1, airbrake_call_count
    end
    WebMock.disable!
  end

  test "should re-raise a wrapped error when redirected to login page" do
    WebMock.enable!
    WebMock.stub_request(:any, INSTAGRAM_ITEM_API_REGEX).to_return(body: '', status: 302, headers: { location: 'https://www.instagram.com/accounts/login/' })

    airbrake_call_count = 0
    arguments_checker = Proc.new do |e|
      airbrake_call_count += 1
      assert_equal Instagram::ApiError, e.class
    end
    PenderAirbrake.stub(:notify, arguments_checker) do
      m = create_media url: "https://www.instagram.com/p/B6_wqMHgQ12/"
      data = m.as_json
      assert_equal 1, airbrake_call_count
    end
    WebMock.disable!
  end

  test "should re-raise a wrapped error when redirected to challenge page" do
    WebMock.enable!
    WebMock.stub_request(:any, INSTAGRAM_PROFILE_API_REGEX).to_return(body: '', status: 302, headers: { location: 'https://www.instagram.com/challenge?' })

    airbrake_call_count = 0
    arguments_checker = Proc.new do |e|
      airbrake_call_count += 1
      assert_equal Instagram::ApiError, e.class
    end
    PenderAirbrake.stub(:notify, arguments_checker) do
      m = create_media url: "https://www.instagram.com/megadeth/"
      data = m.as_json
      assert_equal 1, airbrake_call_count
    end
    WebMock.disable!
  end

  test 'should set item fields from successful api response' do
    response_body = {
      items: [
        {
          user: {
            profile_pic_url: 'https://instagram.net/v/29_n.jpg',
            username: 'c.afpfact',
            full_name: 'AFP Fact Check' 
          },
          image_versions2: {
            candidates: [
              { url: 'https://instagram.net/v/28_n.jpg' } 
            ],
          },
          caption: {
            text: 'Verify misinformation on WhatsApp'
          },
          taken_at: '1659551604'
        }
      ]
    }

    WebMock.enable!
    WebMock.stub_request(:any, INSTAGRAM_ITEM_API_REGEX).to_return(body: response_body.to_json, status: 200)
    
    m = create_media url: 'https://www.instagram.com/p/B6_wqMHgQ12/'
    data = m.as_json
    assert_equal 'B6_wqMHgQ12', data['external_id']
    assert_equal 'item', data['type']
    assert_equal '@c.afpfact', data['username']
    assert_equal 'Verify misinformation on WhatsApp', data['description']
    assert_equal 'Verify misinformation on WhatsApp', data['title']
    assert_equal 'https://instagram.net/v/28_n.jpg', data['picture']
    assert_equal 'AFP Fact Check', data['author_name']
    assert_equal 'https://instagram.com/c.afpfact', data['author_url']
    assert_equal 'https://instagram.net/v/29_n.jpg', data['author_picture']
    assert_equal '2022-08-03T18:33:24.000+00:00', data['published_at']
    WebMock.disable!
  end  
  
  test 'should set profile fields from successful api response' do
    response_body = {
      data: {
        user: {
          biography: "Conserving America’s Great Outdoors and Powering Our Future.",
          full_name: "Department of the Interior",
          profile_pic_url: 'https://instagram.net/v/30_n.jpg',
          username: 'usinterior',
        },
      }
    }
    
    WebMock.enable!
    WebMock.stub_request(:any, INSTAGRAM_PROFILE_API_REGEX).to_return(body: response_body.to_json, status: 200)
  
    m = create_media url: 'https://www.instagram.com/usinterior/'
    data = m.as_json
    assert_equal 'usinterior', data['external_id']
    assert_equal 'profile', data['type']
    assert_equal '@usinterior', data['username']
    assert_equal "Conserving America’s Great Outdoors and Powering Our Future.", data['description']
    assert_equal 'usinterior', data['title']
    assert_equal 'Department of the Interior', data['author_name']
    assert_equal 'https://instagram.net/v/30_n.jpg', data['picture']
    assert_equal 'https://instagram.net/v/30_n.jpg', data['author_picture']
    WebMock.disable!
  end
end 
