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

  def html_doc_from_file(fixture_name)
    doc = ''
    open("test/data/#{fixture_name}.html") { |f| doc = f.read }
    Nokogiri::HTML(doc)
  end

  test "returns provider and type" do
    assert_equal MediaKwaiItem.type, 'kwai_item'
  end

  test "matches known kwai URL patterns, and returns instance on success" do
    assert_nil MediaKwaiItem.match?('https://example.com')
    
    match_one = MediaKwaiItem.match?('https://s.kw.ai/p/1mCb9SSh')
    assert_equal true, match_one.is_a?(MediaKwaiItem)
    match_two = MediaKwaiItem.match?('https://m.kwai.com/photo/150000228494834/5222636779124848117')
    assert_equal true, match_two.is_a?(MediaKwaiItem)
  end

  test "assigns values to hash from the HTML doc" do
    doc = html_doc_from_file('page-kwai')

    data = MediaKwaiItem.new('https://s.kw.ai/p/example').parse_data(doc)
    assert_equal 'A special video', data[:title]
    assert_equal 'A special video', data[:description]
    assert_equal 'Reginaldo Silva2871', data[:author_name]
    assert_equal 'Reginaldo Silva2871', data[:username]
  end

  test "only parses once, caching the data in the object" do
    doc_mock = Minitest::Mock.new
    # Expect at_css is called only once for each attribute, not rerun on second call
    doc_mock.expect(:at_css, OpenStruct.new(text: 'inner text'), ['.info .title'])
    doc_mock.expect(:at_css, OpenStruct.new(text: 'inner text'), ['.name'])

    parser = MediaKwaiItem.new('https://s.kw.ai/p/example')
    parser.parse_data(doc_mock)
    parser.parse_data(doc_mock)

    doc_mock.verify
  end

  test "returns a hash with error message and sends error to Errbit if there is an error parsing" do
    mocked_airbrake = MiniTest::Mock.new
    mocked_airbrake.expect :call, :return_value, [StandardError, Hash]
    
    data = nil
    empty_doc = Nokogiri::HTML('')
    PenderAirbrake.stub(:notify, mocked_airbrake) do
      data = MediaKwaiItem.new('https://s.kw.ai/p/example').parse_data(empty_doc)
    end
    mocked_airbrake.verify
    assert_equal 1, data.keys.count
    assert_equal 5, data[:error][:code]
    assert_match /NoMethodError/, data[:error][:message]
  end
end
