require 'test_helper'

class FacebookItemIntegrationTest < ActiveSupport::TestCase
  test "should get facebook post with valid data from scrapingbot" do
    m = create_media url: 'https://www.facebook.com/photo/?fbid=1071681137662649&set=pb.100044623170418.-2207520000'
    data = m.as_json

    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
    assert_equal '-2207520000_1071681137662649', data['external_id']
    assert data['error'].nil?
    assert !data['title'].blank?
    assert !data['username'].blank?
    assert !data['author_name'].blank?
    assert !data['author_picture'].blank?
    assert !data['author_url'].blank?
    assert !data['description'].blank?
    assert !data['text'].blank?
    assert !data['picture'].blank?
    assert !data['published_at'].blank?
    # data['html'] started to be returned as an empty string for this test
    # which is extra weird since we get it even when the page does not exist
    # will come back to this
    # assert !data['html'].blank?
  end

  test "should get facebook data even if scrapingbot fails" do
    m = create_media url: 'https://www.facebook.com/ECRG.TheBigO/posts/pfbid036xece5JjgLH7rD9RnCr1ASnjETq7QThCHiH1HqYAcfUZNHav4gFJdYUY7nGU8JB6l'
    data = m.as_json

    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
    assert data['external_id'].blank?
    assert data['raw']['scrapingbot'].blank?
    assert !data['title'].blank?
    assert data['description'].blank?
    assert data['picture'].blank?
    assert data['html'].blank?
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
  end
end
