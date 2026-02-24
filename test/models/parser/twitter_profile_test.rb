require 'test_helper'

class TwitterProfileUnitTest < ActiveSupport::TestCase
  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  def empty_doc
    Nokogiri::HTML('')
  end

  def stub_twitter_requests(url, response_file)
    WebMock.stub_request(:get, "https://publish.twitter.com/oembed")
      .with(query: {
        url: url
      })
      .to_return(status: 200, body: response_fixture_from_file(response_file))
  end

  test "returns provider and type" do
    assert_equal Parser::TwitterProfile.type, 'twitter_profile'
  end

  test "matches known URL patterns, and returns instance on success" do
    # Standard profile
    match_zero = Parser::TwitterProfile.match?('https://twitter.com/username/')
    assert_equal true, match_zero.is_a?(Parser::TwitterProfile)
    match_one = Parser::TwitterProfile.match?('https://twitter.com/username')
    assert_equal true, match_one.is_a?(Parser::TwitterProfile)
    match_two = Parser::TwitterProfile.match?('https://twitter.com/user_name')
    assert_equal true, match_two.is_a?(Parser::TwitterProfile)
    
    # Profile with query
    match_three = Parser::TwitterProfile.match?('https://twitter.com/username?ref_src=twsrc%5Etfw')
    assert_equal true, match_three.is_a?(Parser::TwitterProfile)
    match_four = Parser::TwitterProfile.match?('https://twitter.com/username/?t=1')
    assert_equal true, match_four.is_a?(Parser::TwitterProfile)

    # Mobile patterns
    match_five = Parser::TwitterProfile.match?('https://0.twitter.com/username')
    assert_equal true, match_five.is_a?(Parser::TwitterProfile)
    match_six = Parser::TwitterProfile.match?('https://m.twitter.com/username')
    assert_equal true, match_six.is_a?(Parser::TwitterProfile)
    match_seven = Parser::TwitterProfile.match?('https://mobile.twitter.com/username')
    assert_equal true, match_seven.is_a?(Parser::TwitterProfile)
    match_eight = Parser::TwitterProfile.match?('https://mobile.twitter.com/username?ref_src=twsrc%5Etfw')
    assert_equal true, match_eight.is_a?(Parser::TwitterProfile)
  end

  test "does not match pages that should be parsed by pages" do
    assert_nil Parser::TwitterProfile.match?('https://example.com')

    # Blog posts -> should beparsed as pages
    assert_nil Parser::TwitterProfile.match?('https://blog.twitter.com')
    assert_nil Parser::TwitterProfile.match?('https://blog.twitter.com/official/en_us/topics/events/2018/Embrace-Ramadan-with-various-Twitter-only-activations.html')
    assert_nil Parser::TwitterProfile.match?('https://business.twitter.com')
    assert_nil Parser::TwitterProfile.match?('https://business.twitter.com/en/blog/4-tips-Tweeting-live-events.html')
  end

  test "does not match patterns with usernames that are not permitted by twitter" do
    assert_nil Parser::TwitterProfile.match?('https://twitter.com/user whitespace')
    assert_nil Parser::TwitterProfile.match?('https://twitter.com/user*@symbols$')
    assert_nil Parser::TwitterProfile.match?('https://twitter.com/user-–dash—')
    assert_nil Parser::TwitterProfile.match?('https://twitter.com/userwithareallylongusername')
    assert_nil Parser::TwitterProfile.match?('https://twitter.com/me')
  end

  test "matches and extracts username correctly even with a trailing slash" do
    match = 'https://twitter.com/username/'.match(Parser::TwitterProfile.patterns[0])
    username = match['username']
    assert_equal username, 'username'
  end

  test "it makes a get request to the user lookup by username endpoint successfully" do
    stub_configs({'twitter_bearer_token' => 'test' })
    url = 'https://twitter.com/fake_user'
    WebMock.disable_net_connect!
    stub_twitter_requests(url, 'twitter-profile-response-success.json')
    data = Parser::TwitterProfile.new('https://m.twitter.com/fake_user').parse_data(empty_doc)
    assert_equal '@fake_user', data['username']
  end

  test "returns data even if an error is returned" do
    url = 'https://twitter.com/fake_user'
    WebMock.disable_net_connect!
    stub_twitter_requests(url, 'twitter-profile-response-error.json')
    data = Parser::TwitterProfile.new('https://twitter.com/fake_user').parse_data(empty_doc)
    assert_not_nil data['error']
    assert_equal 'fake_user', data['external_id']
    assert_equal 'https://twitter.com/fake_user', data['url']
  end

  test "assigns values to hash from the oembed response" do
    url = 'https://twitter.com/fake_user'
    WebMock.disable_net_connect!
    stub_twitter_requests(url, 'twitter-profile-response-success.json')
    data = Parser::TwitterProfile.new('https://www.twitter.com/fake_user').parse_data(empty_doc)
    assert_equal 'fake_user', data['external_id']
    assert_equal '@fake_user', data['username']
    assert_match 'fake_user', data['title']
    assert_match 'ashokpa61296551', data['author_name']
    assert_match 'https://twitter.com/fake_user', data['url']
    assert_nil data['error']
  end

  test "should parse tweet url with special chars, and strip them" do
    url = 'https://twitter.com/fake_user'
    WebMock.disable_net_connect!
    stub_twitter_requests(url, 'twitter-profile-response-success.json')
    
    parser = Parser::TwitterProfile.new('https://0.twitter.com/fake_user')
    parser.parse_data(empty_doc)
    
    assert_match 'https://twitter.com/fake_user', parser.url

    parser = Parser::TwitterProfile.new('https://m.twitter.com/fake_user')
    parser.parse_data(empty_doc)
    
    assert_match 'https://twitter.com/fake_user', parser.url

    parser = Parser::TwitterProfile.new('https://mobile.twitter.com/fake_user')
    parser.parse_data(empty_doc)
    
    assert_match 'https://twitter.com/fake_user', parser.url
  end

  test "should parse valid link with spaces" do
    url = 'https://twitter.com/fake_user'
    WebMock.disable_net_connect!
    stub_twitter_requests(url, 'twitter-profile-response-success.json')
    data = Parser::TwitterProfile.new(' https://twitter.com/fake_user').parse_data(empty_doc)
    assert_equal 'ashokpa61296551', data['author_name']
  end

  test "#oembed_url returns URL with the instance URL" do
    oembed_url = Parser::TwitterProfile.new('https://twitter.com/fake-account').oembed_url
    assert_equal 'https://publish.twitter.com/oembed?url=https://twitter.com/fake-account', oembed_url
  end

  # test "should parse tweet profile with a query on the url" do
  #   url = 'https://www.twitter.com/fake_user?ref_src=twsrc%5Etfw'
  #   WebMock.disable_net_connect!
  #   stub_twitter_requests(url, 'twitter-profile-response-success.json')

  #   data = Parser::TwitterProfile.new(url).parse_data(empty_doc)
  #   assert_equal 'fake_user', data['external_id']
  #   assert_equal '@fake_user', data['username']
  # end
end
