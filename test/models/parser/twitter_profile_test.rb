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

  def query
    params = {
      "usernames": "fake_user",
      "user.fields": "profile_image_url,name,username,description,created_at,url",
    }
    Rack::Utils.build_query(params)
  end

  def twitter_profile_response_success
    JSON.parse(response_fixture_from_file('twitter-profile-response-success.json'))
  end

  def twitter_profile_response_error
    JSON.parse(response_fixture_from_file('twitter-profile-response-error.json'))
  end

  def stub_profile_lookup
    Parser::TwitterProfile.any_instance.stubs(:user_lookup_by_username)
      .with('fake_user')
  end

  test "returns provider and type" do
    assert_equal Parser::TwitterProfile.type, 'twitter_profile'
  end

  test "matches known URL patterns, and returns instance on success" do
    assert_nil Parser::TwitterProfile.match?('https://example.com')

    # Blog posts -> should beparsed as pages
    assert_nil Parser::TwitterProfile.match?('https://blog.twitter.com')
    assert_nil Parser::TwitterProfile.match?('https://blog.twitter.com/official/en_us/topics/events/2018/Embrace-Ramadan-with-various-Twitter-only-activations.html')
    assert_nil Parser::TwitterProfile.match?('https://business.twitter.com')
    assert_nil Parser::TwitterProfile.match?('https://business.twitter.com/en/blog/4-tips-Tweeting-live-events.html')

    # Standard profile
    match_one = Parser::TwitterProfile.match?('https://twitter.com/meedan')
    assert_equal true, match_one.is_a?(Parser::TwitterProfile)

    # Profile with query
    match_one = Parser::TwitterProfile.match?('https://twitter.com/meedan?ref_src=twsrc%5Etfw')
    assert_equal true, match_one.is_a?(Parser::TwitterProfile)

    # Mobile patterns
    match_two = Parser::TwitterProfile.match?('https://0.twitter.com/meedan')
    assert_equal true, match_two.is_a?(Parser::TwitterProfile)
    match_three = Parser::TwitterProfile.match?('https://m.twitter.com/meedan')
    assert_equal true, match_three.is_a?(Parser::TwitterProfile)
    match_four = Parser::TwitterProfile.match?('https://mobile.twitter.com/meedan')
    assert_equal true, match_four.is_a?(Parser::TwitterProfile)
    match_five = Parser::TwitterProfile.match?('https://mobile.twitter.com/meedan?ref_src=twsrc%5Etfw')
    assert_equal true, match_five.is_a?(Parser::TwitterProfile)
  end

  test "it makes a get request to the user lookup by username endpoint successfully" do
    stub_configs({'twitter_bearer_token' => 'test' })
    
    WebMock.stub_request(:get, "https://api.twitter.com/2/users/by")
      .with(query: query)
      .with(headers: { "Authorization": "Bearer test" })
      .to_return(status: 200, body: response_fixture_from_file('twitter-profile-response-success.json'))

    data = Parser::TwitterProfile.new('https://m.twitter.com/fake_user').parse_data(empty_doc)
    
    assert_equal '2009-04-07T15:40:56.000Z', data['published_at']
    assert_equal '@fake_user', data['username']
  end

  test "it makes a get request to the user lookup by username endpoint and notifies sentry when 404 status is returned" do
    stub_configs({'twitter_bearer_token' => 'test' })

    WebMock.stub_request(:get, "https://api.twitter.com/2/users/by")
      .with(query: query)
      .with(headers: { "Authorization": "Bearer test" })
      .to_return(status: 404, body: response_fixture_from_file('twitter-profile-response-error.json'))

    sentry_call_count = 0
    arguments_checker = Proc.new do |e|
      sentry_call_count += 1
    end
    
    PenderSentry.stub(:notify, arguments_checker) do
      data = Parser::TwitterProfile.new('https://twitter.com/fake_user').parse_data(empty_doc)
      assert_equal 1, sentry_call_count
      assert_not_nil data['error'] 
      assert_match /404/, data['error'][0]['title']      
      assert_match /Not Found Error/, data['error'][0]['detail']   
    end
  end

  test "it makes a get request to the user lookup by username endpoint, notifies sentry when timeout occurs" do
    stub_configs({'twitter_bearer_token' => 'test' })

    WebMock.stub_request(:get, "https://api.twitter.com/2/users/by")
      .with(query: query)
      .with(headers: { "Authorization": "Bearer test" })
      .to_raise(Errno::EHOSTUNREACH)

    sentry_call_count = 0
    arguments_checker = Proc.new do |e|
      sentry_call_count += 1
    end
    
    PenderSentry.stub(:notify, arguments_checker) do
      data = Parser::TwitterProfile.new('https://twitter.com/fake_user').parse_data(empty_doc)
      assert_equal 1, sentry_call_count
      assert_not_nil data['error']        
      assert_match /No route to host/, data['error'][0]['title']  
      assert_nil data['error'][0]['detail']   
    end
  end

  test "returns data even if an error is returned" do
    stub_profile_lookup.returns(twitter_profile_response_error)

    data = Parser::TwitterProfile.new('https://twitter.com/fake_user').parse_data(empty_doc)
    
    assert_not_nil data['error']
    assert_equal 'fake_user', data['external_id']
    assert_equal 'https://twitter.com/fake_user', data['url']
  end

  test "assigns values to hash from the API response" do
    stub_profile_lookup.returns(twitter_profile_response_success)
    
    data = Parser::TwitterProfile.new('https://www.twitter.com/fake_user').parse_data(empty_doc)
    
    assert_equal 'fake_user', data['external_id']
    assert_equal '@fake_user', data['username']
    assert_match /The world's most powerful space telescope/, data['description']
    assert_match 'fake_user', data['title']
    assert_match 'Fake User', data['author_name']
    assert_match 'https://twitter.com/fake_user', data['url']
    assert_match /pbs.twimg.com\/profile_images\/685182791496134658\/Wmyak8D6.jpg/, data['picture']
    assert_match /pbs.twimg.com\/profile_images\/685182791496134658\/Wmyak8D6.jpg/, data['author_picture']
    assert_not_nil data['published_at']
    assert_nil data['error']
  end    
  
  test "should store raw data of profile returned by Twitter API" do
    stub_profile_lookup.returns(twitter_profile_response_success)
    
    data = Parser::TwitterProfile.new('https://www.twitter.com/fake_user').parse_data(empty_doc)
    
    assert_not_nil data['raw']['api']
    assert !data['raw']['api'].empty?
  end    
  
  test "should remove line breaks from Twitter profile description" do
    stub_profile_lookup.returns(twitter_profile_response_success)

    data = Parser::TwitterProfile.new('https://twitter.com/fake_user').parse_data(empty_doc)

    assert_match "Launched: Dec. 25, 2021. First images revealed: July 12, 2022. Verification: https://t.co/ChOEslj1j5", data['description']
  end

  test "should parse tweet url with special chars, and strip them" do
    stub_profile_lookup.returns(twitter_profile_response_success)

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
    stub_profile_lookup.returns(twitter_profile_response_success)
    
    data = Parser::TwitterProfile.new(' https://twitter.com/fake_user').parse_data(empty_doc)
    
    assert_match "Launched: Dec. 25, 2021. First images revealed: July 12, 2022. Verification: https://t.co/ChOEslj1j5", data['description']
  end

  test "#oembed_url returns URL with the instance URL" do
    oembed_url = Parser::TwitterProfile.new('https://twitter.com/fake-account').oembed_url
    assert_equal 'https://publish.twitter.com/oembed?url=https://twitter.com/fake-account', oembed_url
  end

  test "should parse tweet profile with a query on the url" do
    stub_profile_lookup.returns(twitter_profile_response_success)

    data = Parser::TwitterProfile.new('https://www.twitter.com/fake_user?ref_src=twsrc%5Etfw').parse_data(empty_doc)

    assert_equal 'fake_user', data['external_id']
    assert_equal '@fake_user', data['username']
  end
end
