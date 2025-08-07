require 'test_helper'

class FileItemIntegrationTest < ActiveSupport::TestCase
  test "should return an errored object (for now) when parsing an image file URL, and avoid setting binary data as raw oembed" do
    m = create_media url: 'https://christa.town//img/christatown.gif'
    data = m.process_and_return_json
    assert_equal 'item', data['type']
    assert_equal 'file', data['provider']
    assert_equal 'https://christa.town/img/christatown.gif', data['title']
    assert data['oembed'].present?
    assert data['raw']['oembed'].blank?
  end
end

class FileItemUnitTest <  ActiveSupport::TestCase
  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  def doc
    nil
  end

  test "returns provider and type" do
    assert_equal Parser::FileItem.type, 'file_item'
  end

  test "matches known URL patterns for file types, and returns instance on success" do
    assert_nil Parser::FileItem.match?('https://example.com/index')
    assert_nil Parser::FileItem.match?('https://example.com/index.html')

    assert Parser::FileItem.match?('https://example.com/piglet.png').is_a?(Parser::FileItem)
    assert Parser::FileItem.match?('https://example.com/piglet.PNG').is_a?(Parser::FileItem)
    assert Parser::FileItem.match?('https://example.com/piglet.gif').is_a?(Parser::FileItem)
    assert Parser::FileItem.match?('https://example.com/piglet.jpg').is_a?(Parser::FileItem)
    assert Parser::FileItem.match?('https://example.com/piglet.jpeg').is_a?(Parser::FileItem)
    assert Parser::FileItem.match?('https://example.com/piglet.bmp').is_a?(Parser::FileItem)
    assert Parser::FileItem.match?('https://example.com/piglet.tif').is_a?(Parser::FileItem)
    assert Parser::FileItem.match?('https://example.com/piglet.tiff').is_a?(Parser::FileItem)
    assert Parser::FileItem.match?('https://example.com/piglet.pdf').is_a?(Parser::FileItem)
    assert Parser::FileItem.match?('https://example.com/piglet.mp3').is_a?(Parser::FileItem)
    assert Parser::FileItem.match?('https://example.com/piglet.mp4').is_a?(Parser::FileItem)
    assert Parser::FileItem.match?('https://example.com/piglet.ogg').is_a?(Parser::FileItem)
    assert Parser::FileItem.match?('https://example.com/piglet.mov').is_a?(Parser::FileItem)
    assert Parser::FileItem.match?('https://example.com/piglet.csv').is_a?(Parser::FileItem)
    assert Parser::FileItem.match?('https://example.com/piglet.svg').is_a?(Parser::FileItem)
    assert Parser::FileItem.match?('https://example.com/piglet.wav').is_a?(Parser::FileItem)
  end

  # We want to move this to using a head request and react based on the header info
  test "passes data straight through, for now" do
    data = Parser::FileItem.new('https://example.com/piglet.png').parse_data(nil)
    assert data['title'].blank?
  end
end
