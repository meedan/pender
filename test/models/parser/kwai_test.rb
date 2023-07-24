require 'test_helper'

class KwaiIntegrationTest < ActiveSupport::TestCase
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

class KwaiUnitTest <  ActiveSupport::TestCase
  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  test "returns provider and type" do
    assert_equal Parser::KwaiItem.type, 'kwai_item'
  end

  test "matches known kwai URL patterns, and returns instance on success" do
    assert_nil Parser::KwaiItem.match?('https://example.com')
    
    match_one = Parser::KwaiItem.match?('https://s.kw.ai/p/1mCb9SSh')
    assert_equal true, match_one.is_a?(Parser::KwaiItem)
    match_two = Parser::KwaiItem.match?('https://m.kwai.com/photo/150000228494834/5222636779124848117')
    assert_equal true, match_two.is_a?(Parser::KwaiItem)
  end

  test "assigns values to hash from the HTML doc" do
    doc = response_fixture_from_file('kwai-page.html', parse_as: :html)

    data = Parser::KwaiItem.new('https://s.kw.ai/p/example').parse_data(doc)
    assert_equal 'A special video', data[:title]
    assert_equal 'A special video', data[:description]
    assert_equal 'Reginaldo Silva2871', data[:author_name]
    assert_equal 'Reginaldo Silva2871', data[:username]
  end
end
