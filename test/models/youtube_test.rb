require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class YoutubeTest < ActiveSupport::TestCase
  test "should parse YouTube user" do
    m = create_media url: 'https://www.youtube.com/user/portadosfundos'
    data = m.as_json
    assert_equal 'Porta dos Fundos', data['title']
    assert_equal 'portadosfundos', data['username']
    assert_equal 'Porta dos Fundos', data['author_name']
    assert_equal 'channel', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
    assert_equal data[:raw][:api][:video_count].to_s, data['video_count']
    assert_equal data[:raw][:api][:subscriber_count].to_s, data['subscriber_count']
  end

  test "should parse YouTube channel" do
    m = create_media url: 'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ'
    data = m.as_json
    assert_equal 'Iron Maiden', data['title']
    assert_equal 'ironmaiden', data['username'].downcase
    assert_equal 'Iron Maiden', data['author_name']
    assert_equal 'channel', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
    assert_equal data[:raw][:api][:video_count].to_s, data['video_count']
    assert_equal data[:raw][:api][:subscriber_count].to_s, data['subscriber_count']
  end

  test "should not cache result" do
    Media.any_instance.stubs(:parse).once
    create_media url: 'https://www.youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQ'
    Media.any_instance.unstub(:parse)
  end

  test "should cache result" do
    create_media url: 'https://www.youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQ'
    Media.any_instance.stubs(:parse).never
    create_media url: 'https://www.youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQ'
    Media.any_instance.unstub(:parse)
  end

  test "should parse YouTube user with slash" do
    m = create_media url: 'https://www.youtube.com/user/portadosfundos/'
    data = m.as_json
    assert_equal 'Porta dos Fundos', data['title']
    assert_equal 'portadosfundos', data['username']
    assert_equal 'channel', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse YouTube channel with slash" do
    m = create_media url: 'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ/'
    data = m.as_json
    assert_equal 'Iron Maiden', data['title']
    assert_equal 'ironmaiden', data['username']
    assert_equal 'channel', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should return YouTube fields" do
    m = create_media url: 'https://www.youtube.com/watch?v=mtLxD7r4BZQ'
    data = m.as_json
    assert_match /^http/, data['author_picture']
    assert_equal data[:raw][:api]['channel_title'], data['username']
    assert_equal data[:raw][:api]['description'], data['description']
    assert_equal data[:raw][:api]['title'], data['title']
    assert_equal data[:raw][:api]['thumbnails']['maxres']['url'], data['picture']
    assert_equal data[:raw][:api]['embed_html'], data['html']
    assert_equal data[:raw][:api]['channel_title'], data['author_name']
    assert_equal 'https://www.youtube.com/channel/' + data[:raw][:api]['channel_id'], data['author_url']
    assert_equal data[:raw][:api]['published_at'], data['published_at']
  end

  test "should store data of item returned by Youtube API" do
    m = create_media url: 'https://www.youtube.com/watch?v=mtLxD7r4BZQ'
    data = m.as_json
    assert data['raw']['api'].is_a? Hash
    assert !data['raw']['api'].empty?

    assert !data['title'].blank?
    assert_not_nil data['published_at']
  end

  test "should store data of profile returned by Youtube API" do
    m = create_media url: 'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ'
    data = m.as_json
    assert data['raw']['api'].is_a? Hash
    assert !data['raw']['api'].empty?

    assert !data['title'].blank?
    assert !data['description'].blank?
    assert !data['published_at'].blank?
    assert !data['picture'].blank?
  end

  test "should store oembed data of a youtube item" do
    m = create_media url: 'https://www.youtube.com/watch?v=mtLxD7r4BZQ'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal "https:\/\/www.youtube.com\/", data['raw']['oembed']['provider_url']
    assert_equal "YouTube", data['raw']['oembed']['provider_name']
  end

  test "should store oembed data of a youtube profile" do
    m = create_media url: 'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal 'ironmaiden', data['raw']['oembed']['author_name']
    assert_equal 'Iron Maiden', data['raw']['oembed']['title']
  end

  test "should get all thumbnails available and set the highest resolution as picture for item" do
    urls = {
      'https://www.youtube.com/watch?v=yyougTzksw8' => { available: ['default', 'high', 'medium'], best: 'high' },
      'https://www.youtube.com/watch?v=8Rd5diO16yM' => { available: ['default', 'high', 'medium', 'standard'], best: 'standard' },
      'https://www.youtube.com/watch?v=WxnN05vOuSM' => { available: ['default', 'high', 'medium', 'standard', 'maxres'], best: 'maxres' }
    }
    urls.each_pair do |url, thumbnails|
      m = create_media url: url
      data = m.as_json
      assert_equal thumbnails[:available].sort, data[:raw][:api]['thumbnails'].keys.sort
      assert_equal data[:raw][:api]['thumbnails'][thumbnails[:best]]['url'], data['picture']
    end
  end

  test "should get all thumbnails available and set the highest resolution as picture for profile" do
    urls = {
      'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ' => { available: ['default', 'high', 'medium'], best: 'high' },
      'https://www.youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQ' => { available: ['default', 'high', 'medium'], best: 'high' }
    }
    urls.each_pair do |url, thumbnails|
      m = create_media url: url
      data = m.as_json
      assert_equal thumbnails[:available].sort, data[:raw][:api]['thumbnails'].keys.sort
      assert_equal data[:raw][:api]['thumbnails'][thumbnails[:best]]['url'], data['picture']
    end
  end

  test "should not crash when parsing a deleted YouTube video" do
    url = 'https://www.youtube.com/watch?v=6q_Tcyeq5fk&feature=youtu.be'
    m = create_media url: url
    data = m.as_json
    assert_equal 'YouTube', data['username']
    assert_equal 'Deleted video', data['title']
    assert_equal 'This video is unavailable.', data['description']
    assert_equal 'https://www.youtube.com/channel/UCBR8-60-B28hp2BmDPdntcQ', data['author_url']
    assert_equal '', data[:raw][:api]['thumbnails']
    assert_equal '', data[:raw][:api]['embed_html']
    assert_equal '', data['picture']
    assert_equal '', data['html']
  end

end
