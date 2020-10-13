require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class FacebookProfileTest < ActiveSupport::TestCase

  test "should parse Facebook page" do
    m = create_media url: 'https://www.facebook.com/ironmaiden/?fref=ts'
    data = m.as_json
    assert_match 'Iron Maiden', data['title']
    assert_match 'ironmaiden', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'page', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse Facebook page with numeric id" do
    m = create_media url: 'https://www.facebook.com/pages/Meedan/105510962816034?fref=ts'
    data = m.as_json
    assert_match 'Meedan', data['title']
    assert_match 'Meedan', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'page', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse Facebook with numeric id" do
    m = create_media url: 'http://facebook.com/513415662050479'
    data = m.as_json
    assert_match 'https://www.facebook.com/NautilusMag', data['url']
    assert_match 'Nautilus Magazine', data['title']
    assert_match 'NautilusMag', data['username']
    assert !data['description'].blank?
    assert_match 'https://www.facebook.com/NautilusMag', data['author_url']
    assert_not_nil data['author_picture']
    assert_match 'Nautilus Magazine', data['author_name']
    assert_not_nil data['picture']
  end

  test "should get likes for Facebook page" do
    m = create_media url: 'https://www.facebook.com/ironmaiden/?fref=ts'
    data = m.as_json
    assert_match /^[0-9]+$/, data['likes'].to_s
  end

  test "should parse Arabic Facebook page" do
    m = create_media url: 'https://www.facebook.com/%D8%A7%D9%84%D9%85%D8%B1%D9%83%D8%B2-%D8%A7%D9%84%D8%AB%D9%82%D8%A7%D9%81%D9%8A-%D8%A7%D9%84%D9%82%D8%A8%D8%B7%D9%8A-%D8%A7%D9%84%D8%A3%D8%B1%D8%AB%D9%88%D8%B0%D9%83%D8%B3%D9%8A-%D8%A8%D8%A7%D9%84%D9%85%D8%A7%D9%86%D9%8A%D8%A7-179240385797/'
    data = m.as_json
    assert_equal 'المركز الثقافي القبطي الأرثوذكسي بالمانيا', data['title']
  end

  test "should parse Arabic URLs" do
    assert_nothing_raised do
      m = create_media url: 'https://www.facebook.com/إدارة-تموين-أبنوب-217188161807938/'
      data = m.as_json
    end
  end

  test "should get Facebook name when metatag is not present" do
    m = create_media url: 'https://www.facebook.com/ironmaiden/'
    doc = ''
    open('test/data/fb-page-without-og-title-metatag.html') { |f| doc = f.read }
    Media.any_instance.stubs(:get_facebook_profile_page).returns(Nokogiri::HTML(doc))

    data = m.as_json
    assert data['error'].nil?
    assert_equal 'Page without `og:title` defined', data['title']
    Media.any_instance.unstub(:get_facebook_profile_page)
  end

  test "should fallback to default Facebook title" do
    m = create_media url: 'https://ca.ios.ba/files/meedan/facebook.html'
    assert_equal 'Facebook', m.get_facebook_name
  end

  test "should have external id for profile" do
    m = create_media url: 'https://www.facebook.com/ironmaiden'
    data = m.as_json
    assert_equal 172685102050, data['external_id']
  end

  test "should add not found error and return empty html" do
    url = 'https://www.facebook.com/ldfkgjdfghodhg'

    m = create_media url: url
    data = m.as_json
    assert_equal '', data[:html]
    assert_equal LapisConstants::ErrorCodes::const_get('NOT_FOUND'), data[:error][:code]
    assert_equal 'URL Not Found', data[:error][:message]
  end

  test "should not get metrics from Facebook page" do
    Media.unstub(:request_metrics_from_facebook)
    PenderAirbrake.stubs(:notify).never
    url = 'https://www.facebook.com/ironmaiden/'
    m = Media.new url: url
    data = m.as_json
    assert_nil data['metrics']['facebook']
    PenderAirbrake.unstub(:notify)
  end
end
