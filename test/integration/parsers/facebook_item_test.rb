require 'test_helper'

class FacebookItemIntegrationTest < ActiveSupport::TestCase
  test "should get facebook post with valid data from crowdtangle" do
    m = create_media url: 'https://www.facebook.com/144585402276277/posts/1127489833985824'
    data = m.as_json

    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
    assert_equal '144585402276277_1127489833985824', data['external_id']
    assert data['error'].blank?
    assert !data['title'].blank?
    assert !data['username'].blank?
    assert !data['author_name'].blank?
    assert !data['author_picture'].blank?
    assert !data['author_url'].blank?
    assert !data['description'].blank?
    assert !data['text'].blank?
    assert !data['picture'].blank?
    assert !data['subtype'].blank?
    assert !data['published_at'].blank?
  end
end
