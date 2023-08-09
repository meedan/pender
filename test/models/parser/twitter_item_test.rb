require 'test_helper'

class TwitterItemUnitTest < ActiveSupport::TestCase
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
      "ids": "1111111111111111111",
      "tweet.fields": "author_id,created_at,text",
      "expansions": "author_id,attachments.media_keys",
      "user.fields": "profile_image_url,username,url",
      "media.fields": "url",
    }
    Rack::Utils.build_query(params)
  end

  def twitter_item_response_success
    JSON.parse(response_fixture_from_file('twitter-item-response-success.json'))
  end

  def twitter_item_response_error
    JSON.parse(response_fixture_from_file('twitter-item-response-error.json'))
  end

  def stub_tweet_lookup
    Parser::TwitterItem.any_instance.stubs(:tweet_lookup)
      .with('1111111111111111111')
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

  test "it makes a get request to the tweet lookup endpoint successfully" do
    stub_configs({'twitter_bearer_token' => 'test' })
    
    WebMock.stub_request(:get, "https://api.twitter.com/2/tweets")
      .with(query: query)
      .with(headers: { "Authorization": "Bearer test" })
      .to_return(status: 200, body: response_fixture_from_file('twitter-item-response-success.json'))

    data = Parser::TwitterItem.new('https://m.twitter.com/fake_user/status/1111111111111111111').parse_data(empty_doc)
    
    assert_equal '1111111111111111111', data['external_id']
    assert_equal '@fake_user', data['username']
  end

  test "it makes a get request to the tweet lookup endpoint and raises an error when 401 is returned" do
    stub_configs({'twitter_bearer_token' => 'test' })

    WebMock.stub_request(:get, "https://api.twitter.com/2/tweets")
      .with(query: query)
      .with(headers: { "Authorization": "Bearer test" })
      .to_return(status: 401)

    assert_raises ProviderTwitter::ApiError do
      Parser::TwitterItem.new('https://m.twitter.com/fake_user/status/1111111111111111111').parse_data(empty_doc)
    end
  end

  test "it makes a get request to the tweet lookup endpoint, raises an error when 500 is returned and notifies sentry" do
    stub_configs({'twitter_bearer_token' => 'test' })

    WebMock.stub_request(:get, "https://api.twitter.com/2/tweets")
      .with(query: query)
      .with(headers: { "Authorization": "Bearer test" })
      .to_return(status: 500, body: response_fixture_from_file('twitter-item-response-error.json'))

      sentry_call_count = 0
      arguments_checker = Proc.new do |e|
        sentry_call_count += 1
      end
      
      PenderSentry.stub(:notify, arguments_checker) do
        assert_raises ProviderTwitter::ApiError do
          Parser::TwitterItem.new('https://twitter.com/fake_user/status/1111111111111111111').parse_data(empty_doc)
        end
        assert_equal 1, sentry_call_count
      end        
  end

  test "should store data of post returned by twitter API" do
    stub_tweet_lookup.returns(twitter_item_response_success)

    data = Parser::TwitterItem.new('https://twitter.com/fake_user/status/1111111111111111111').parse_data(empty_doc)

    assert data['raw']['api'].is_a? Hash
    assert !data['raw']['api'].empty?
  end

  test "sets the author_url o be https://twitter.com/<user_handle> even if an error is returned" do
    stub_tweet_lookup.returns(twitter_item_response_error)

    data = Parser::TwitterItem.new('https://twitter.com/fake_user/status/1111111111111111111').parse_data(empty_doc)
    
    assert_not_nil data['error']
    assert_equal 'https://twitter.com/fake_user', data['author_url']
  end

  test "returns an unique title even if an error is returned" do
    stub_tweet_lookup.returns(twitter_item_response_error)

    data = Parser::TwitterItem.new('https://twitter.com/fake_user/status/1111111111111111111').parse_data(empty_doc)
    
    assert_not_nil data['error']
    assert_equal 'https://twitter.com/fake_user/status/1111111111111111111', data['title']
  end

  test "should remove line breaks from Twitter item title" do
    stub_tweet_lookup.returns(twitter_item_response_success)

    data = Parser::TwitterItem.new('https://twitter.com/fake_user/status/1111111111111111111').parse_data(empty_doc)

    assert_match 'Youths! Webb observed galaxy cluster El Gordo', data['title']
  end

  test "should parse tweet url with special chars, and strip them" do
    stub_tweet_lookup.returns(twitter_item_response_success)

    parser = Parser::TwitterItem.new('https://twitter.com/#!/fake_user/status/1111111111111111111')
    data = parser.parse_data(empty_doc)
    
    assert_match 'https://twitter.com/fake_user/status/1111111111111111111', parser.url

    parser = Parser::TwitterItem.new('https://twitter.com/%23!/fake_user/status/1111111111111111111')
    data = parser.parse_data(empty_doc)
    
    assert_match 'https://twitter.com/fake_user/status/1111111111111111111', parser.url
  end

  test "#oembed_url returns URL with the instance URL" do
    oembed_url = Parser::TwitterItem.new('https://twitter.com/fake-account/status/1234').oembed_url
    assert_equal 'https://publish.twitter.com/oembed?url=https://twitter.com/fake-account/status/1234', oembed_url
  end

  test "should parse valid link with spaces" do
    stub_tweet_lookup.returns(twitter_item_response_success)

    data = Parser::TwitterItem.new(' https://twitter.com/fake_user/status/1111111111111111111').parse_data(empty_doc)

    assert_match 'Youths! Webb observed galaxy cluster El Gordo', data['title']
  end

  test "should fill in html when html parsing fails but API works" do
    stub_tweet_lookup.returns(twitter_item_response_success)

    data = Parser::TwitterItem.new('https://twitter.com/fake_user/status/1111111111111111111').parse_data(empty_doc)

    assert_match "<a href=\"https://twitter.com/fake_user/status/1111111111111111111\"", data[:html]
  end
end
