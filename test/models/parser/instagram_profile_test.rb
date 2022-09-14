require 'test_helper'

class InstagramProfileIntegrationTest < ActiveSupport::TestCase
  test "should parse Instagram profile link for real" do
    m = Media.new url: 'https://www.instagram.com/ironmaiden'
    data = m.as_json
    assert_equal 'profile', data['type']
    assert_equal 'ironmaiden', data['external_id']
    assert_equal '@ironmaiden', data['username']
    assert_match 'ironmaiden', data['title']
    assert !data['description'].blank?
  end
end

class InstagramProfileUnitTest < ActiveSupport::TestCase
  INSTAGRAM_PROFILE_API_REGEX = /i.instagram.com\/api\/v1\/users\/web_profile_info\//

  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  def graphql
    @graphql ||= response_fixture_from_file('instagram-profile-graphql.json')
  end

  def doc
    @doc ||= response_fixture_from_file('instagram-profile-page.html', parse_as: :html)
  end

  test "returns provider and type" do
    assert_equal Parser::InstagramProfile.type, 'instagram_profile'
  end

  test "matches known URL patterns, and returns instance on success" do
    assert_nil Parser::InstagramProfile.match?('https://example.com')
    
    match_one = Parser::InstagramProfile.match?('https://www.instagram.com/fake-account')
    assert_equal true, match_one.is_a?(Parser::InstagramProfile)
  end

  test "should set profile defaults upon error" do
    WebMock.stub_request(:any, INSTAGRAM_PROFILE_API_REGEX).to_raise(Net::ReadTimeout.new("Raised in test"))

    data = Parser::InstagramProfile.new('https://www.instagram.com/fake-account').parse_data(doc, nil)

    assert_equal 'fake-account', data['external_id']
    assert_equal '@fake-account', data['username']
    assert_match 'fake-account', data['title']
    assert_match 'https://www.instagram.com/fake-account', data['description']
  end

  test "should return error on item data when link can't be found" do
    WebMock.stub_request(:any, INSTAGRAM_PROFILE_API_REGEX).to_return(status: 404)

    data = {}
    airbrake_call_count = 0
    arguments_checker = Proc.new do |e|
      airbrake_call_count += 1
      assert_equal ProviderInstagram::ApiError, e.class
    end

    PenderAirbrake.stub(:notify, arguments_checker) do
      data = Parser::InstagramProfile.new('https://www.instagram.com/fake-account').parse_data(doc, nil)
      assert_equal 1, airbrake_call_count
    end
    assert_match /ProviderInstagram::ApiResponseCodeError/, data['error']['message']
  end

  test "should re-raise a wrapped error when parsing fails" do
    WebMock.stub_request(:any, INSTAGRAM_PROFILE_API_REGEX).to_return(body: 'asdf', status: 200)

    data = {}
    airbrake_call_count = 0
    arguments_checker = Proc.new do |e|
      airbrake_call_count += 1
      assert_equal ProviderInstagram::ApiError, e.class
    end
    PenderAirbrake.stub(:notify, arguments_checker) do
      data = Parser::InstagramProfile.new('https://www.instagram.com/fake-account').parse_data(doc)
      assert_equal 1, airbrake_call_count
    end
    assert_match /ProviderInstagram::ApiError/, data['error']['message']
  end

  test "should re-raise a wrapped error when redirected to a page that requires authentication" do
    WebMock.stub_request(:any, INSTAGRAM_PROFILE_API_REGEX).to_return(body: '', status: 302, headers: { location: 'https://www.instagram.com/challenge?' })

    data = {}
    airbrake_call_count = 0
    arguments_checker = Proc.new do |e|
      airbrake_call_count += 1
      assert_equal ProviderInstagram::ApiError, e.class
    end
    PenderAirbrake.stub(:notify, arguments_checker) do
      data = Parser::InstagramProfile.new('https://www.instagram.com/fake-account').parse_data(doc, nil)
      assert_equal 1, airbrake_call_count
    end
    assert_match /ProviderInstagram::ApiAuthenticationError/, data['error']['message']
  end

  test 'should set profile fields from successful api response' do
    WebMock.stub_request(:any, INSTAGRAM_PROFILE_API_REGEX).to_return(body: graphql, status: 200)

    data = Parser::InstagramProfile.new('https://www.instagram.com/fake-account').parse_data(doc)
    assert_equal 'fake-account', data['external_id']
    assert_equal '@fake-account', data['username']
    assert_match /New album out September 2/, data['description']
    assert_equal 'fake-account', data['title']
    assert_equal 'Megadeth', data['author_name']
    assert_match /scontent-sjc3-1.cdninstagram.com\/v\/t51.2885-19\/298966074_744587416797579_6159007932562050088_n.jpg/, data['picture']
    assert_match /scontent-sjc3-1.cdninstagram.com\/v\/t51.2885-19\/298966074_744587416797579_6159007932562050088_n.jpg/, data['author_picture']
    assert data['published_at'].blank?
  end

  test "should store raw data of profile returned by Instagram request" do
    WebMock.stub_request(:any, INSTAGRAM_PROFILE_API_REGEX).to_return(body: graphql, status: 200)
    
    data = Parser::InstagramProfile.new('https://www.instagram.com/fake-account').parse_data(doc, nil)

    assert_not_nil data['raw']['api']
    assert !data['raw']['api'].empty?
  end
end 
