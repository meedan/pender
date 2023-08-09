require 'test_helper'

class TwitterItemIntegrationTest < ActiveSupport::TestCase
  test "should parse tweet from a successful link" do
    m = create_media url: 'https://twitter.com/caiosba/status/742779467521773568'
    data = m.as_json
    assert_match 'I\'ll be talking in @rubyconfbr this year! More details soon...', data['title']
    assert_match 'Caio Almeida', data['author_name']
    assert_match '@caiosba', data['username']
    assert_nil data['picture']
    assert_not_nil data['author_picture']
  end

  test "should return data even if a the twitter item does not exist" do
    m = create_media url: 'https://twitter.com/caiosba/status/1111111111111111111'
    data = m.as_json
    assert_match 'https://twitter.com/caiosba/status/1111111111111111111', data['title']
    assert_match 'caiosba', data['author_name']
    assert_match '@caiosba', data['username']
    assert_nil data['picture']
    assert_not_nil data['author_picture']
  end
end

