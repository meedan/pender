require 'test_helper'

class TwitterItemIntegrationTest < ActiveSupport::TestCase
  test "should parse tweet" do
    # skip("twitter api key is not currently working")
    m = create_media url: 'https://twitter.com/caiosba/status/742779467521773568'
    data = m.as_json
    assert_match 'I\'ll be talking in @rubyconfbr this year! More details soon...', data['title']
    assert_match 'Caio Almeida', data['author_name']
    assert_match '@caiosba', data['username']
    assert_nil data['picture']
    assert_not_nil data['author_picture']
  end

  test "should parse valid link with spaces" do
    # skip("twitter api key is not currently working")
    m = create_media url: ' https://twitter.com/caiosba/status/742779467521773568 '
    data = m.as_json
    assert_match 'I\'ll be talking in @rubyconfbr this year! More details soon...', data['title']
    assert_match 'Caio Almeida', data['author_name']
    assert_match '@caiosba', data['username']
    assert_nil data['picture']
    assert_not_nil data['author_picture']
  end

  test "should fill in html when html parsing fails but API works" do
    # skip("twitter api key is not currently working")
    url = 'https://twitter.com/codinghorror/status/1276934067015974912'
    OpenURI.stubs(:open_uri).raises(OpenURI::HTTPError.new('','429 Too Many Requests'))
    m = create_media url: url
    data = m.as_json
    assert_match /twitter-tweet.*#{url}/, data[:html]
  end
  
  test "should not parse a twitter post when passing the twitter api bearer token is missing" do
    # skip("this might be broke befcause of twitter api changes - needs fixing")
    key = create_api_key application_settings: { config: { twitter_bearer_token: '' } }
    m = create_media url: 'https://twitter.com/cal_fire/status/919029734847025152', key: key
    assert_equal '', PenderConfig.get(:twitter_bearer_token)
    data = m.as_json
    assert_equal m.url, data['title']
    assert_match "401 Unauthorized", data['error']['message']
  end

  test "should store oembed data of a twitter profile" do
    # skip("twitter api key is not currently working")
    m = create_media url: 'https://twitter.com/meedan'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal "https:\/\/twitter.com", data['raw']['oembed']['provider_url']
    assert_equal "Twitter", data['raw']['oembed']['provider_name']
  end
end

