require 'test_helper'

class DropboxIntegrationTest < ActiveSupport::TestCase
  test "should parse Kwai URL" do
    m = create_media url: 'https://www.dropbox.com/s/fa5w5erdkrdu4uo/How%20to%20use%20the%20Public%20folder.rtf?dl=0'
    data = m.as_json
    assert_equal 'item', data['type']
    assert_equal 'dropbox', data['provider']
    assert_equal 'How to use the Public folder.rtf', data['title']
    assert_equal 'Shared with Dropbox', data['description']
    assert !data['picture'].blank?
    assert_nil data['error']
  end
end

class DropboxUnitTest <  ActiveSupport::TestCase
  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  def doc
    @doc ||= response_fixture_from_file('dropbox-page.html', parse_as: :html)
  end

  test "returns provider and type" do
    assert_equal Parser::DropboxItem.type, 'dropbox_item'
  end

  test "matches known URL patterns, and returns instance on success" do
    assert_nil Parser::DropboxItem.match?('https://example.com')
    
    match_one = Parser::DropboxItem.match?('https://www.dropbox.com/s/fake-url/example.txt')
    assert_equal true, match_one.is_a?(Parser::DropboxItem)
    match_two = Parser::DropboxItem.match?('https://dropboxusercontent.com/s/fake-url/example.txt')
    assert_equal true, match_two.is_a?(Parser::DropboxItem)
    match_three = Parser::DropboxItem.match?('https://www.dropbox.com/sh/fake-url/example.txt')
    assert_equal true, match_three.is_a?(Parser::DropboxItem)
  end

  test "assigns values to hash from the HTML doc" do
    data = Parser::DropboxItem.new('https://www.dropbox.com/sh/fake-url/example.txt').parse_data(doc)
    assert_equal 'How to use the Public folder.rtf', data[:title]
    assert_equal 'This was totally shared with Dropbox', data[:description]
    assert_equal 'https://www.dropbox.com/static/metaserver/static/images/spectrum-icons/generated/content/content-docx-large.png', data[:picture]
  end

  test "should fall back to fetching information from URL" do
    empty_doc = Nokogiri::HTML('')

    data = Parser::DropboxItem.new('https://www.dropbox.com/sh/fake-url/How%20to%20use%20the%20Public%20folder.rtf').parse_data(empty_doc)
    assert_equal 'How to use the Public folder.rtf', data[:title]
    assert_equal 'Shared with Dropbox', data[:description]
  end

  test "returns a hash with error message and sends error to Errbit if there is an error parsing" do
    mocked_airbrake = MiniTest::Mock.new
    mocked_airbrake.expect :call, :return_value, [StandardError, Hash]

    Parser::DropboxItem.any_instance.stubs(:get_metadata_from_tags).raises(NoMethodError.new("Faking in test"))

    data = nil
    PenderAirbrake.stub(:notify, mocked_airbrake) do
      data = Parser::DropboxItem.new('https://www.dropbox.com/sh/fake-url/example.txt').parse_data(doc)
    end
    mocked_airbrake.verify
    assert_equal 5, data[:error][:code]
    assert_match /NoMethodError/, data[:error][:message]
  end
end
