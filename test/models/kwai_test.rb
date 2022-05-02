require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class KwaiTest < ActiveSupport::TestCase
  test "should parse Kwai URL" do
    m = create_media url: 'https://s.kw.ai/p/1mCb9SSh'
    data = m.as_json
    assert_equal 'Reginaldo Silva2871', data['username']
    assert_equal 'item', data['type']
    assert_equal 'kwai', data['provider']
    assert_equal 'Reginaldo Silva2871', data['author_name']
    assert_equal 'F. Francisco', data['title']
    assert_equal 'F. Francisco', data['description']
    assert_nil data['error']
  end
end
