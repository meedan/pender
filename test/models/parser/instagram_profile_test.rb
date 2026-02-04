require 'test_helper'

class InstagramProfileIntegrationTest < ActiveSupport::TestCase
  test "should parse Instagram profile link for real" do
    m = Media.new url: 'https://www.instagram.com/ironmaiden?absolute_url_processed=1'
    data = m.process_and_return_json
    assert_equal 'profile', data['type']
    assert data['title'].present?
  end
end

class InstagramProfileUnitTest < ActiveSupport::TestCase
  INSTAGRAM_PROFILE_API_REGEX = /apify.com/

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

    match_two = Parser::InstagramProfile.match?('https://www.instagram.com/fake-account?foo=bar')
    assert_equal true, match_two.is_a?(Parser::InstagramProfile)
  end

  test "should set profile defaults upon error" do
    WebMock.stub_request(:any, INSTAGRAM_PROFILE_API_REGEX).to_raise(Net::ReadTimeout.new("Raised in test"))

    data = Parser::InstagramProfile.new('https://www.instagram.com/fake-account').parse_data(doc)

    assert_equal 'fake-account', data['external_id']
    assert_equal '@fake-account', data['username']
    assert_match 'fake-account', data['title']
    assert_match 'https://www.instagram.com/fake-account', data['description']
  end

  test 'should set profile fields from successful Apify response' do
    WebMock.stub_request(:post, INSTAGRAM_PROFILE_API_REGEX)
           .to_return(body: '[{"inputUrl": "https://www.instagram.com/fake-account", "id": "fake-account", "caption": "This is the profile bio", "username": "fakeaccount", "profilePicUrl": "https://example.com/profile.jpg", "fullName": "Fake Account", "timestamp": "2024-08-21T17:27:17.000Z"}]', status: 200)
  
    data = Parser::InstagramProfile.new('https://www.instagram.com/fake-account').parse_data(doc)
    
    assert_equal 'fake-account', data['external_id']
    assert_equal '@fake-account', data['username']
    assert_equal "https://www.instagram.com/fake-account", data['description']
    assert_equal "fake-account", data['title']
  end
end 
