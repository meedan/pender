require 'test_helper'

class FacebookProfileIntegrationTest < ActiveSupport::TestCase
  test "should parse Facebook page" do
    media = create_media url: 'https://www.facebook.com/ironmaiden/?fref=ts'
    data = media.as_json
    
    assert !data['title'].blank?
    assert_equal 'ironmaiden', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'profile', data['type']

    # Requires login, so cannot fetch ID from HTML
    assert data['id'].blank?
    assert data['external_id'].blank?
  end

  test "should parse Facebook page with numeric id" do
    media = create_media url: 'https://www.facebook.com/pages/Meedan/105510962816034?fref=ts'
    data = media.as_json
    
    assert !data['title'].blank?
    assert_equal 'Meedan', data['username']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
    assert_equal 'facebook', data['provider']
    assert_equal 'profile', data['type']

    # Parsed from URL
    assert_equal '105510962816034', data['id']
    assert_equal '105510962816034', data['external_id']
  end

  test "should return data even if Facebook page does not exist" do
    media = create_media url: 'https://www.facebook.com/pages/fakepage/1111111111111'
    data = media.as_json

    assert_match(/facebook.com\/pages\/fakepage\/1111111111111/, data['title'])
    assert_equal 'fakepage', data['username']
    assert data['description'].blank?
    assert data['picture'].blank?
    assert data['published_at'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'profile', data['type']
  end
end

