require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class MediaTest < ActiveSupport::TestCase
  test "should create media" do
    assert_kind_of Media, create_media
  end

  test "should have URL" do
    m = create_media url: 'http://foo.bar'
    assert_equal 'http://foo.bar', m.url
  end

  test "should parse YouTube user" do
    m = create_media url: 'https://www.youtube.com/user/portadosfundos'
    assert_equal 'Porta dos Fundos', m.as_json['title']
    assert_equal 'portadosfundos', m.as_json['username']
    assert_equal 'user', m.as_json['subtype']
  end

  test "should parse YouTube channel" do
    m = create_media url: 'https://www.youtube.com/channel/UCQDZiehIRKS6o9AlX1g8lSw'
    assert_equal 'Documentarios em Portugues', m.as_json['title']
    assert_equal 'DocumentariosemPortugues', m.as_json['username']
    assert_equal 'channel', m.as_json['subtype']
  end

  test "should not cache result" do
    Media.any_instance.stubs(:parse).once
    create_media url: 'https://www.youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQ'
  end

  test "should cache result" do
    create_media url: 'https://www.youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQ'
    Media.any_instance.stubs(:parse).never
    create_media url: 'https://www.youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQ'
  end

  test "should parse Twitter profile" do
    m = create_media url: 'https://twitter.com/caiosba'
    assert_equal 'Caio Almeida', m.as_json['title']
    assert_equal 'caiosba', m.as_json['username']
    assert_equal 'twitter', m.as_json['provider']
  end
end
