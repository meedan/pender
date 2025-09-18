require 'test_helper'

class InstagramItemIntegrationTest < ActiveSupport::TestCase
  test "should get Instagram post with valid data from apify" do
    m = create_media url: 'https://www.instagram.com/p/C-8LjWmuTx1/'
    data = m.process_and_return_json

    assert_equal 'instagram', data['provider']
    assert_equal 'item', data['type']
    assert_equal 'C-8LjWmuTx1', data['external_id']
    assert data['error'].nil?
    assert !data['title'].blank?
    assert !data['username'].blank?
    assert !data['author_name'].blank?
    assert !data['author_picture'].blank?
    assert !data['author_url'].blank?
    assert !data['description'].blank?
    assert !data['picture'].blank?
    assert !data['published_at'].blank?
  end

  test "should get Instagram data even if Apify fails" do
    m = create_media url: 'https://www.instagram.com/p/nonexistent_post/'
    data = m.process_and_return_json

    assert !data['title'].blank?
    assert !data['username'].blank?
  end
end
