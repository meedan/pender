require 'test_helper'

class TiktokProfileIntegrationTest < ActiveSupport::TestCase
  test "should parse Tiktok profile for real" do
    m = create_media url: 'https://www.tiktok.com/@scout2015'
    data = m.as_json
    assert_equal '@scout2015', data['username']
    assert_equal 'profile', data['type']
    assert_equal 'tiktok', data['provider']
    assert !data['title'].blank?
    assert !data['author_name'].blank?
    assert_equal '@scout2015', data['external_id']
    assert_match 'https://www.tiktok.com/@scout2015', m.url
  end
end
