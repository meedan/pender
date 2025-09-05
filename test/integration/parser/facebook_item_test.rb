require 'test_helper'

class FacebookItemIntegrationTest < ActiveSupport::TestCase
  test "should get facebook post with valid data from apify" do
    m = create_media url: 'https://www.facebook.com/natgeo/posts/pfbid02vFSkQz1Htm7UCRmPVLt8PSEhfgZqyGEQpyAfSCotSPYbdMWy2y4hZSFcMpecSw1Dl'
    data = m.process_and_return_json

    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
    assert_equal '100044623170418_1072984447532318', data['external_id']
    assert data['error'].nil?
    assert !data['title'].blank?
    assert !data['username'].blank?
    assert !data['author_name'].blank?
    assert !data['description'].blank?
    assert !data['text'].blank?
    assert !data['picture'].blank?
    assert !data['published_at'].blank?
  end

  test "should get facebook data even if apify fails" do
    m = create_media url: 'https://www.facebook.com/ECRG.TheBigO/posts/pfbid036xece5JjgLH7rD9RnCr1ASnjETq7QThCHiH1HqYAcfUZNHav4gFJdYUY7nGU8JB6l'
    data = m.process_and_return_json

    assert data['error'].nil?
    assert !data['title'].blank?
    assert !data['username'].blank?
    assert !data['author_name'].blank?
  end

  test "should return data even if post does not exist" do
    m = create_media url: 'https://www.facebook.com/111111111111111/posts/1111111111111111'
    data = m.process_and_return_json

    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
    assert_equal '111111111111111_1111111111111111', data['external_id']
    assert_match(/facebook.com\/111111111111111\/posts\/1111111111111111/, data['title'])
    assert_match(/facebook.com\/111111111111111\/posts\/1111111111111111/, data['description'])
    assert_equal '', data['username']
    assert_equal '', data['author_name']
    assert_equal '', data['author_picture']
    assert_equal '', data['author_url']
    assert_equal '', data['picture']
    assert_equal '', data['published_at']
  end
end
