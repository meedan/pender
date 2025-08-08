require 'test_helper'

class TiktokItemIntegrationTest < ActiveSupport::TestCase
  test "should parse Tiktok item for real" do
    m = create_media url: 'https://www.tiktok.com/@scout2015/video/7094001694408756526?is_from_webapp=1&sender_device=pc&web_id=7064890017416234497'
    data = m.process_and_return_json
    assert_equal 'tiktok', data['provider']
    assert_equal 'item', data['type']
    assert_kind_of String, data['title']
    assert_kind_of String, data['author_name']
  end

  test "should parse short TikTok link" do
    m = create_media url: 'https://vm.tiktok.com/JLPfuep/'
    data = m.process_and_return_json
    assert_equal 'item', data['type']
    assert_equal 'item', data['type']
    assert_kind_of String, data['title']
    assert_kind_of String, data['author_name']
  end
end
