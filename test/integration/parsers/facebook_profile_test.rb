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
end

