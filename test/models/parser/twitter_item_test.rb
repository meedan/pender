require 'test_helper'

class TwitterItemIntegrationTest < ActiveSupport::TestCase
  test "should parse tweet" do
    m = create_media url: 'https://twitter.com/caiosba/status/742779467521773568'
    data = m.as_json
    assert_match 'I\'ll be talking in @rubyconfbr this year! More details soon...', data['title']
    assert_match 'Caio Almeida', data['author_name']
    assert_match '@caiosba', data['username']
    assert_nil data['picture']
    assert_not_nil data['author_picture']
  end

  test "should parse valid link with spaces" do
    m = create_media url: ' https://twitter.com/caiosba/status/742779467521773568 '
    data = m.as_json
    assert_match 'I\'ll be talking in @rubyconfbr this year! More details soon...', data['title']
    assert_match 'Caio Almeida', data['author_name']
    assert_match '@caiosba', data['username']
    assert_nil data['picture']
    assert_not_nil data['author_picture']
  end

  test "should fill in html when html parsing fails but API works" do
    url = 'https://twitter.com/codinghorror/status/1276934067015974912'
    OpenURI.stubs(:open_uri).raises(OpenURI::HTTPError.new('','429 Too Many Requests'))
    m = create_media url: url
    data = m.as_json
    assert_match /twitter-tweet.*#{url}/, data[:html]
  end
  
  test "should not parse a twitter post when passing the twitter api key or subkey missing" do
    key = create_api_key application_settings: { config: { twitter_consumer_key: 'consumer_key', twitter_consumer_secret: '' } }
    m = create_media url: 'https://twitter.com/cal_fire/status/919029734847025152', key: key
    assert_equal 'consumer_key', PenderConfig.get(:twitter_consumer_key)
    assert_equal '', PenderConfig.get(:twitter_consumer_secret)
    data = m.as_json
    assert_equal m.url, data['title']
    assert_match "Twitter::Error::Unauthorized", data['raw']['api']['error']['message']
    PenderConfig.current = nil

    key = create_api_key application_settings: { config: { twitter_consumer_key: '' } }
    m = create_media url: 'https://twitter.com/cal_fire/status/919029734847025152' , key: key
    assert_equal '', PenderConfig.get(:twitter_consumer_key)
    data = m.as_json
    assert_equal m.url, data['title']
    assert_match "Twitter::Error::Unauthorized", data['raw']['api']['error']['message']
  end
end

class TwitterItemUnitTest < ActiveSupport::TestCase
  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  def fake_twitter_user
    return @fake_twitter_user unless @fake_twitter_user.blank?
    # https://github.com/sferik/twitter/blob/master/lib/twitter/user.rb
    api_response = response_fixture_from_file('twitter-profile-response.json', parse_as: :json)
    @fake_twitter_user = Twitter::User.new(api_response.with_indifferent_access)
  end

  def fake_tweet
    return @fake_tweet unless @fake_tweet.blank?
    # https://github.com/sferik/twitter/blob/master/lib/twitter/tweet.rb
    api_response = response_fixture_from_file('twitter-item-response.json', parse_as: :json)
    @fake_tweet = Twitter::Tweet.new(api_response.with_indifferent_access)
  end

  test "returns provider and type" do
    assert_equal Parser::TwitterItem.type, 'twitter_item'
  end

  test "matches known URL patterns, and returns instance on success" do
    assert_nil Parser::TwitterItem.match?('https://example.com')

    # Blog posts -> should beparsed as pages
    assert_nil Parser::TwitterItem.match?('https://blog.twitter.com')
    assert_nil Parser::TwitterItem.match?('https://blog.twitter.com/official/en_us/topics/events/2018/Embrace-Ramadan-with-various-Twitter-only-activations.html')
    assert_nil Parser::TwitterItem.match?('https://business.twitter.com')
    assert_nil Parser::TwitterItem.match?('https://business.twitter.com/en/blog/4-tips-Tweeting-live-events.html')

    # Standard profile
    match_one = Parser::TwitterItem.match?('https://twitter.com/meedan/status/12345678')
    assert_equal true, match_one.is_a?(Parser::TwitterItem)
    match_two = Parser::TwitterItem.match?('https://wwww.twitter.com/meedan/status/12345678')
    assert_equal true, match_two.is_a?(Parser::TwitterItem)

    # Mobile patterns
    match_three = Parser::TwitterItem.match?('https://0.twitter.com/meedan/status/12345678')
    assert_equal true, match_three.is_a?(Parser::TwitterItem)
    match_four = Parser::TwitterItem.match?('https://m.twitter.com/meedan/status/12345678')
    assert_equal true, match_four.is_a?(Parser::TwitterItem)
    match_five = Parser::TwitterItem.match?('https://mobile.twitter.com/meedan/status/12345678')
    assert_equal true, match_five.is_a?(Parser::TwitterItem)

    # Special characters
    match_six = Parser::TwitterItem.match?('http://twitter.com/#!/salmaeldaly/status/45532711472992256')
    assert_equal true, match_six.is_a?(Parser::TwitterItem)
    match_seven = Parser::TwitterItem.match?('http://twitter.com/%23!/salmaeldaly/status/45532711472992256')
    assert_equal true, match_seven.is_a?(Parser::TwitterItem)
  end

  test "assigns values to hash from the API response" do
    Twitter::REST::Client.any_instance.stubs(:status).returns(fake_tweet)
    Twitter::REST::Client.any_instance.stubs(:user).returns(fake_twitter_user)

    data = Parser::TwitterItem.new('https://twitter.com/fakeaccount/status/123456789').parse_data('')

    assert_equal '123456789', data['external_id']
    assert_equal '@fakeaccount', data['username']
    assert_match /I'll be talking in @rubyconfbr this year!/, data['title']
    assert_match /I'll be talking in @rubyconfbr this year!/, data['description']
    assert_nil data['picture']
    assert_match /pbs.twimg.com\/profile_images\/1217299193217388544\/znpkNtDr.jpg/, data['author_picture']
    assert_match /<blockquote class="twitter-tweet">/, data['html']    
    assert_match 'Caio Almeida', data['author_name']
    assert_match /twitter.com\/TEDTalks/, data['author_url']
    assert_not_nil data['published_at']

    assert_nil data['error']
  end

  test "should store data of post returned by twitter API" do
    Twitter::REST::Client.any_instance.stubs(:status).returns(fake_tweet)
    Twitter::REST::Client.any_instance.stubs(:user).returns(fake_twitter_user)

    data = Parser::TwitterItem.new('https://twitter.com/fakeaccount/status/123456789').parse_data('')

    assert data['raw']['api'].is_a? Hash
    assert !data['raw']['api'].empty?
  end

  test "should store oembed data of a twitter post" do
    skip "needs oembed"
    Twitter::REST::Client.any_instance.stubs(:status).returns(fake_tweet)
    Twitter::REST::Client.any_instance.stubs(:user).returns(fake_twitter_user)

    data = Parser::TwitterItem.new('https://twitter.com/fakeaccount/status/123456789').parse_data('')

    assert data['raw']['oembed'].is_a? Hash
    assert_equal "https:\/\/twitter.com", data['raw']['oembed']['provider_url']
    assert_equal "Twitter", data['raw']['oembed']['provider_name']
  end

  # I'm not confident this is testing anything about HTML decoding as written
  test "should decode html entities" do
    tweet = Twitter::Tweet.new(
      id: "123",
      text: " [update] between Calistoga and Santa Rosa (Napa & Sonoma County) is now 35,270 acres and 44% contained. "
    )
    Twitter::REST::Client.any_instance.stubs(:status).returns(tweet)
    Twitter::REST::Client.any_instance.stubs(:user).returns(fake_twitter_user)

    data = Parser::TwitterItem.new('https://twitter.com/fakeaccount/status/123456789').parse_data('')
    assert_no_match /&amp;/, data['title']
  end

  test "should throw Pender::ApiLimitReached when Twitter::Error::TooManyRequests is thrown when parsing tweet" do
    Twitter::REST::Client.any_instance.stubs(:status).raises(Twitter::Error::TooManyRequests)

    assert_raises Pender::ApiLimitReached do
      Parser::TwitterItem.new('https://twitter.com/fake-account/status/123456789').parse_data('')
    end
  end

  test "logs error resulting from non-ratelimit tweet lookup, and return default values with html blank" do
    Twitter::REST::Client.any_instance.stubs(:status).raises(Twitter::Error::NotFound)
    Twitter::REST::Client.any_instance.stubs(:user).returns(fake_twitter_user)

    data = {}
    airbrake_call_count = 0
    arguments_checker = Proc.new do |e|
      airbrake_call_count += 1
      assert_equal Twitter::Error::NotFound, e.class
    end

    PenderAirbrake.stub(:notify, arguments_checker) do
      data = Parser::TwitterItem.new('https://twitter.com/fake-account/status/123456789').parse_data('')
      assert_equal 1, airbrake_call_count
    end
    assert_match /Twitter::Error::NotFound/, data['error']['message']
    assert_equal "123456789", data['external_id']
    assert_equal "@fake-account", data['username']
    assert data['html'].empty?
  end

  # This swallows rate limiting errors, which we're surfacing in a different
  # exception catching block in the same class. It also doesn't surface errors.
  # We may want to reconsider both of these things for consistency.
  test "logs error resulting from looking up user information, and returns tweet info" do
    Twitter::REST::Client.any_instance.stubs(:status).returns(fake_tweet)
    Twitter::REST::Client.any_instance.stubs(:user).raises(Twitter::Error)

    data = {}
    airbrake_call_count = 0
    arguments_checker = Proc.new do |e|
      airbrake_call_count += 1
      assert_equal Twitter::Error, e.class
    end

    PenderAirbrake.stub(:notify, arguments_checker) do
      data = Parser::TwitterItem.new('https://twitter.com/fakeaccount/status/123456789').parse_data('')
      assert_equal 1, airbrake_call_count
    end
    assert_nil data['error']
    assert_equal "123456789", data['external_id']
    assert_equal "@fakeaccount", data['username']
    assert_match /I'll be talking in @rubyconfbr this year!/, data['title']
  end

  # This is current behavior, but I wonder if we might want something like https://twitter.com/fakeaccount
  test "falls back to top_url when user information can't be retrieved" do
    Twitter::REST::Client.any_instance.stubs(:status).returns(fake_tweet)
    Twitter::REST::Client.any_instance.stubs(:user).raises(Twitter::Error)

    data = Parser::TwitterItem.new('https://twitter.com/fakeaccount/status/123456789').parse_data('')
    assert_nil data['error']
    assert_equal 'https://twitter.com', data['author_url']
  end

  test "should remove line breaks from Twitter item title" do
    tweet = Twitter::Tweet.new(
      id: '123',
      text: "LA Times- USC Dornsife Sunday Poll: \n Donald Trump Retains 2 Point \n Lead Over Hillary"
    )
    Twitter::REST::Client.any_instance.stubs(:status).returns(tweet)
    Twitter::REST::Client.any_instance.stubs(:user).returns(fake_twitter_user)

    data = Parser::TwitterItem.new('https://twitter.com/fake-account/status/123456789').parse_data('')
    assert_match 'LA Times- USC Dornsife Sunday Poll: Donald Trump Retains 2 Point Lead Over Hillary', data['title']
  end

  test "should parse tweet url with special chars, and strip them" do
    Twitter::REST::Client.any_instance.stubs(:status).returns(fake_tweet)
    Twitter::REST::Client.any_instance.stubs(:user).returns(fake_twitter_user)

    parser = Parser::TwitterItem.new('https://twitter.com/#!/salmaeldaly/status/45532711472992256')
    data = parser.parse_data('')
    
    assert_match 'https://twitter.com/salmaeldaly/status/45532711472992256', parser.url

    parser = Parser::TwitterItem.new('https://twitter.com/%23!/salmaeldaly/status/45532711472992256')
    data = parser.parse_data('')
    
    assert_match 'https://twitter.com/salmaeldaly/status/45532711472992256', parser.url
  end

  # I'm not confident this is testing anything about truncation as written
  test "should get all information of a truncated tweet" do
    tweet = Twitter::Tweet.new(
      id: "123",
      full_text: "Anti immigrant graffiti in a portajon on a residential construction site in Mtn Brook, AL. Job has about 50% Latino workers. https://t.co/bS5vI4Jq7I",
      truncated: true,
      entities:  {
        media: [
          { media_url_https: "https://pbs.twimg.com/media/C7dYir1VMAAi46b.jpg" }
        ]
      }
    )
    Twitter::REST::Client.any_instance.stubs(:status).returns(tweet)
    Twitter::REST::Client.any_instance.stubs(:user).returns(fake_twitter_user)

    data = Parser::TwitterItem.new('https://twitter.com/fake-account/status/123456789').parse_data('')

    assert_equal 'https://pbs.twimg.com/media/C7dYir1VMAAi46b.jpg', data['picture']
  end

  test "#oembed_url returns URL with the instance URL" do
    oembed_url = Parser::TwitterItem.new('https://twitter.com/fake-account/status/1234').oembed_url
    assert_equal 'https://publish.twitter.com/oembed?url=https://twitter.com/fake-account/status/1234', oembed_url
  end
end
