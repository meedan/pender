require 'test_helper'

class KwaiIntegrationTest < ActiveSupport::TestCase
  test "should parse Kwai URL" do
    m = create_media url: 'https://kwai-video.com/p/md02RsCS'
    data = m.as_json

    assert_kind_of String, data['title']
    assert_kind_of String, data['description']
    assert_match(/arthur\s*virgilio/i, data['username'])
    assert_match(/arthur\s*virgilio/i, data['author_name'])
    assert_equal 'kwai', data['provider']
    assert_equal 'item', data['type']
  end

  test "should return data even if Kwai URL does not exist" do
    m = create_media url: 'https://kwai-video.com/p/aaaaaaaa'
    data = m.as_json

    assert_equal 'https://kwai-video.com/p/aaaaaaaa', data['title']
    assert data['description'].blank?
    assert data['username'].blank?
    assert_equal 'kwai', data['provider']
    assert_equal 'item', data['type']
    assert_nil data['error']
  end
end
