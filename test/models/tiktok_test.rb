require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class TiktokTest < ActiveSupport::TestCase
  test "should parse Tiktok profile" do
    m = create_media url: 'https://www.tiktok.com/@scout2015'
    data = m.as_json
    assert_equal '@scout2015', data['username']
    assert_equal 'profile', data['type']
    assert_equal 'tiktok', data['provider']
    assert !data['title'].blank?
    assert !data['author_name'].blank?
    assert_equal '@scout2015', data['external_id']
    assert_not_nil data['picture']
    assert_match 'https://www.tiktok.com/@scout2015', m.url
    assert_nil data['error']
  end

  test "should parse Tiktok link" do
    m = create_media url: 'https://www.tiktok.com/@scout2015/video/6771039287917038854'
    data = m.as_json
    assert_equal '@scout2015', data['username']
    assert_equal 'item', data['type']
    assert_match /Who agrees/, data['title']
    assert_match 'Scout and Suki', data['author_name']
    assert_equal '6771039287917038854', data['external_id']
    assert_match 'https://www.tiktok.com/@scout2015', data['author_url']
    assert_match /^http/, data['picture']
    assert_nil data['error']
  end

end
