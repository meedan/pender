require 'test_helper'

class FacebookProfileIntegrationTest < ActiveSupport::TestCase
  test "should parse Facebook page" do
    m = create_media url: 'https://www.facebook.com/ironmaiden/?fref=ts'
    data = m.as_json
    assert !data['title'].blank?
    assert_match 'ironmaiden', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'profile', data['type']

    # Requires login, so cannot fetch ID from HTML
    assert data['id'].blank?
    assert data['external_id'].blank?
  end

  test "should parse Facebook page with numeric id" do
    m = create_media url: 'https://www.facebook.com/pages/Meedan/105510962816034?fref=ts'
    data = m.as_json
    assert !data['title'].blank?
    assert_match 'Meedan', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'profile', data['type']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']

    # Parsed from URL
    assert_equal '105510962816034', data['id']
    assert_equal '105510962816034', data['external_id']
  end

  test "should parse Facebook with numeric id" do
    m = create_media url: 'http://facebook.com/513415662050479'
    data = m.as_json
    assert_match /facebook.com\/(NautilusMag|513415662050479)/, data['url']
    assert !data['title'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'profile', data['type']

    # Parsed from URL
    assert_equal '513415662050479', data['id']
    assert_equal '513415662050479', data['external_id']
  end

  test "should parse Arabic Facebook page" do
    m = create_media url: 'https://www.facebook.com/%D8%A7%D9%84%D9%85%D8%B1%D9%83%D8%B2-%D8%A7%D9%84%D8%AB%D9%82%D8%A7%D9%81%D9%8A-%D8%A7%D9%84%D9%82%D8%A8%D8%B7%D9%8A-%D8%A7%D9%84%D8%A3%D8%B1%D8%AB%D9%88%D8%B0%D9%83%D8%B3%D9%8A-%D8%A8%D8%A7%D9%84%D9%85%D8%A7%D9%86%D9%8A%D8%A7-179240385797/'
    data = m.as_json
    assert !data['title'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'profile', data['type']
  end

  test "should parse Arabic URLs" do
    assert_nothing_raised do
      m = create_media url: 'https://www.facebook.com/إدارة-تموين-أبنوب-217188161807938/'
      data = m.as_json
    end
  end

  test "should store oembed data of a public facebook page" do
    m = create_media url: 'https://www.facebook.com/heymeedan'
    m.as_json

    assert m.data['raw']['oembed'].is_a?(Hash), "Expected #{m.data['raw']['oembed']} to be a Hash"
    assert !m.data['oembed']['author_name'].blank?
    assert !m.data['oembed']['title'].blank?
  end
end

