require 'test_helper'

class TwitterProfileIntegrationTest < ActiveSupport::TestCase
  test "should parse shortened URL" do
    skip("twitter api key is not currently working")
    m = create_media url: 'http://bit.ly/23qFxCn'
    data = m.as_json
    assert_equal 'https://twitter.com/caiosba', data['url']
    assert_not_nil data['title']
    assert_match '@caiosba', data['username']
    assert_equal 'twitter', data['provider']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should store oembed data of a twitter profile" do
    skip("twitter api key is not currently working")
    m = create_media url: 'https://twitter.com/meedan'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal "https:\/\/twitter.com", data['raw']['oembed']['provider_url']
    assert_equal "Twitter", data['raw']['oembed']['provider_name']
  end
end

class TwitterProfileUnitTest < ActiveSupport::TestCase
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

  def empty_doc
    Nokogiri::HTML('')
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

    # Mobile patterns
    match_two = Parser::TwitterProfile.match?('https://0.twitter.com/meedan')
    assert_equal true, match_two.is_a?(Parser::TwitterProfile)
    match_three = Parser::TwitterProfile.match?('https://m.twitter.com/meedan')
    assert_equal true, match_three.is_a?(Parser::TwitterProfile)
    match_four = Parser::TwitterProfile.match?('https://mobile.twitter.com/meedan')
    assert_equal true, match_four.is_a?(Parser::TwitterProfile)
  end

  test "should send Twitter error to Errbit and return default values" do
    skip("this might be broke befcause of twitter api changes - needs fixing")
    Twitter::REST::Client.any_instance.stubs(:user).raises(Twitter::Error)

    data = {}
    sentry_call_count = 0
    arguments_checker = Proc.new do |e|
      sentry_call_count += 1
      assert_equal Twitter::Error, e.class
    end

    PenderSentry.stub(:notify, arguments_checker) do
      data = Parser::TwitterProfile.new('https://www.twitter.com/fakeaccount').parse_data(nil)
      assert_equal 1, sentry_call_count
    end
    assert_match /Twitter::Error/, data['error']['message']
    assert_equal "fakeaccount", data['title']
    assert_equal "https://twitter.com/fakeaccount", data['url']
    assert_equal "fakeaccount", data['external_id']
    assert_equal "@fakeaccount", data['username']
    assert_equal "fakeaccount", data['author_name']
  end

  test "assigns values to hash from the API response" do
    skip("this might be broke befcause of twitter api changes - needs fixing")
    Twitter::REST::Client.any_instance.stubs(:user).returns(fake_twitter_user)

    data = Parser::TwitterProfile.new('https://www.twitter.com/fakeaccount').parse_data(empty_doc)

    assert_equal 'fakeaccount', data['external_id']
    assert_equal '@fakeaccount', data['username']
    assert_match /TED is a nonprofit devoted to spreading ideas/, data['description']
    assert_match 'TED Talks', data['title']
    assert_match 'TED Talks', data['author_name']

    assert_match 'https://twitter.com/fakeaccount', data['url']
    assert_match /pbs.twimg.com\/profile_images\/877631054525472768\/Xp5FAPD5.jpg/, data['picture']
    assert_match /pbs.twimg.com\/profile_images\/877631054525472768\/Xp5FAPD5.jpg/, data['author_picture']
    assert_not_nil data['published_at']

    assert_nil data['error']
  end

  test "should store raw data of profile returned by Twitter API" do
    skip("this might be broke befcause of twitter api changes - needs fixing")
    Twitter::REST::Client.any_instance.stubs(:user).returns(fake_twitter_user)

    data = Parser::TwitterProfile.new('https://www.twitter.com/fakeaccount').parse_data(empty_doc)

    assert_not_nil data['raw']['api']
    assert !data['raw']['api'].empty?
  end

  test "should throw Pender::Exception::ApiLimitReached when Twitter::Error::TooManyRequests is thrown" do
    skip("this might be broke befcause of twitter api changes - needs fixing")
    Twitter::REST::Client.any_instance.stubs(:user).raises(Twitter::Error::TooManyRequests)

    assert_raises Pender::Exception::ApiLimitReached do
      Parser::TwitterProfile.new('https://twitter.com/fake-account').parse_data(empty_doc)
    end
  end

  test "#oembed_url returns URL with the instance URL" do
    oembed_url = Parser::TwitterProfile.new('https://twitter.com/fake-account').oembed_url
    assert_equal 'https://publish.twitter.com/oembed?url=https://twitter.com/fake-account', oembed_url
  end
end
