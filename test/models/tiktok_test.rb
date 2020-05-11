require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class TiktokTest < ActiveSupport::TestCase
  test "should parse Tiktok profile" do
    m = create_media url: 'https://www.tiktok.com/@scout2015'
    d = m.as_json
    assert_equal '@scout2015', d['username']
    assert_equal 'profile', d['type']
    assert_equal 'Scout and Suki on TikTok', d['title']
    assert_equal 'Scout and Suki on TikTok', d['author_name']
    assert_equal '@scout2015', d['external_id']
    assert_not_nil d['picture']
    assert_equal 'https://www.tiktok.com/@scout2015', m.url
    assert_nil d['error']
  end

  test "should parse Tiktok link" do
    m = create_media url: 'https://www.tiktok.com/@scout2015/video/6771039287917038854'
    d = m.as_json
    assert_equal '@scout2015', d['username']
    assert_equal 'item', d['type']
    assert_match /Who agrees/, d['title']
    assert_equal 'Scout and Suki', d['author_name']
    assert_equal '6771039287917038854', d['external_id']
    assert_equal 'https://www.tiktok.com/@scout2015', d['author_url']
    assert_match /^http/, d['picture']
    assert_nil d['error']
  end

end
