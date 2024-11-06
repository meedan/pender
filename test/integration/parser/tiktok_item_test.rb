require 'test_helper'

class TiktokItemIntegrationTest < ActiveSupport::TestCase
  test "should parse Tiktok item for real" do
    m = create_media url: 'https://www.tiktok.com/@scout2015/video/7094001694408756526?is_from_webapp=1&sender_device=pc&web_id=7064890017416234497'
    data = m.as_json
    assert_equal 'item', data['type']
    assert_match /Should we keep/, data['title']
    assert_match /Scout.+Suki/, data['author_name']
    assert_equal '7094001694408756526', data['external_id']
    assert_match 'https://www.tiktok.com/@scout2015', data['author_url']
    assert_match /^http/, data['picture']
    assert_nil data['error']
    assert_equal '@scout2015', data['username']
  end

  test "should parse short TikTok link" do
    skip "the shortlink below is no longer resolving, and we need to make sure shortlinks are still supported"

    m = create_media url: 'https://vt.tiktok.com/ZSduCHt6g/?k=1'
    data = m.as_json
    assert_equal 'item', data['type']
    assert_match /Sabotage/, data['title']
    assert_match /Michael/, data['author_name']
    assert_equal '7090122043793984795', data['external_id']
    assert_match 'https://www.tiktok.com/@ken28gallardo', data['author_url']
    assert_nil data['error']
    assert_equal '@ken28gallardo', data['username']
  end
end
