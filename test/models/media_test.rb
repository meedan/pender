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
    m = create_media url: 'https://www.youtube.com/user/MeedanTube'
    assert_equal 'MeedanTube', m.as_json['title']
  end

  test "should parse YouTube channel" do
    m = create_media url: 'https://www.youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQ'
    assert_equal 'Barbixas', m.as_json['title']
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
end
