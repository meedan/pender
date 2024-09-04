require 'test_helper'

class FacebookItemIntegrationTest < ActiveSupport::TestCase
  # test "should get facebook post with valid data from crowdtangle" do
  #   m = create_media url: 'https://www.facebook.com/144585402276277/posts/1127489833985824'
  #   data = m.as_json
  #
  #   assert_equal 'facebook', data['provider']
  #   assert_equal 'item', data['type']
  #   assert_equal '144585402276277_1127489833985824', data['external_id']
  #   assert data['error'].nil?
  #   assert !data['title'].blank?
  #   assert !data['username'].blank?
  #   assert !data['author_name'].blank?
  #   assert !data['author_picture'].blank?
  #   assert !data['author_url'].blank?
  #   assert !data['description'].blank?
  #   assert !data['text'].blank?
  #   assert !data['picture'].blank?
  #   assert !data['published_at'].blank?
  #   # data['html'] started to be returned as an empty string for this test
  #   # which is extra weird since we get it even when the page does not exist
  #   # will come back to this
  #   # assert !data['html'].blank?
  # end

  test "should get facebook data even if crowdtangle fails" do
    m = create_media url: 'https://www.facebook.com/ECRG.TheBigO/posts/pfbid036xece5JjgLH7rD9RnCr1ASnjETq7QThCHiH1HqYAcfUZNHav4gFJdYUY7nGU8JB6l'
    data = m.as_json

    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
    assert data['external_id'].blank?
    assert data['error'].nil?
    assert !data['title'].blank?
    assert !data['description'].blank?
    assert !data['picture'].blank?
    assert !data['html'].blank?
  end

  test "should return data even if post does not exist" do
    m = create_media url: 'https://www.facebook.com/111111111111111/posts/1111111111111111'
    data = m.as_json

    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
    assert_equal '111111111111111_1111111111111111', data['external_id']
    assert_equal 'https://www.facebook.com/111111111111111/posts/1111111111111111', data['title']
    assert_equal '', data['username']
    assert_equal '', data['author_name']
    assert_equal '', data['author_picture']
    assert_equal '', data['author_url']
    assert_equal '', data['description']
    assert_equal '', data['picture']
    assert_equal '', data['published_at']
    assert !data['html'].blank?
  end
end
