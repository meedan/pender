require 'test_helper'

class TwitterProfileIntegrationTest < ActiveSupport::TestCase
  test "should parse shortened URL" do
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

  test "should return data even if a the twitter profile does not exist" do
    m = create_media url: 'https://twitter.com/dlihfbfyhugsrb'
    data = m.as_json
    assert_equal 'https://twitter.com/dlihfbfyhugsrb', data['url']
    assert_equal 'dlihfbfyhugsrb', data['title']
    assert_match '@dlihfbfyhugsrb', data['username']
    assert_equal 'twitter', data['provider']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
    assert_match /Could not find user/, data['error'][0]['detail']
    assert_match /Not Found Error/, data['error'][0]['title']
  end
end
