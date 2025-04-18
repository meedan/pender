require 'test_helper'

class YoutubeItemIntegrationTest < ActiveSupport::TestCase
  test "should parse YouTube item" do
    m = create_media url: 'https://youtube.com/watch?v=S49CN57Y58o'
    data = m.as_json
    assert_equal 'Full Length Freight Trains! 1 Hour of Trains!', data['title']
    assert_equal 'CoasterFan2105', data['username']
    assert_equal 'CoasterFan2105', data['author_name']
    assert_equal 'item', data['type']
    assert_equal 'youtube', data['provider']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should store oembed data of a youtube item" do
    RequestHelper.stubs(:get_html).returns(Nokogiri::HTML("<link rel='alternate' type='application/json+oembed' href='https://www.youtube.com/oembed?format=json&url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DfHatsiQvDWc' title='RubyConf Portugal 2016 - Best Of'>"))
    m = create_media url: 'https://www.youtube.com/watch?v=fHatsiQvDWc' 
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal "https:\/\/www.youtube.com\/", data['raw']['oembed']['provider_url']
    assert_equal "YouTube", data['raw']['oembed']['provider_name']
  end

  test "should ignore consent page and parse youtube item" do
    consent_page = 'https://consent.youtube.com/m?continue=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fapp%3Ddesktop%26v%3Dp8y8IzeF9u8%26feature%3Dyoutu.be%26ab_channel%3DDra.RobertaLacerda&gl=IE&m=0&pc=yt&uxe=23983172&hl=en&src=1'
    response = ''
    response.stubs(:code).returns('302')
    response.stubs(:header).returns({ 'location' => consent_page })
    url = 'https://www.youtube.com/watch?v=bEAdvXRJ9mU'
    Media.any_instance.stubs(:request_media_url).with(url).returns(response)
    m = create_media url: url
    data = m.as_json
    assert_equal 'item', data['type']
    assert_equal 'youtube', data['provider']
    assert_match /Co·Insights: Fostering community collaboration/, data['title']
    assert_match /Co·Insights is a NSF-proposal to create/, data['description']
    assert_equal 'https://www.youtube.com/channel/UCKyn6nCR9fXFhDL-WeeyOzQ', data['author_url']
    assert !data['html'].blank?
    assert_equal 'https://www.youtube.com/watch?v=bEAdvXRJ9mU', m.url
  end
end

class YoutubeItemUnitTest < ActiveSupport::TestCase
  def setup
    isolated_setup

    Yt::Channel.any_instance.stubs(:thumbnail_url)
  end

  def teardown
    isolated_teardown
  end
  
  def minimal_video
    @minimal_video ||= Yt::Video.new(
      id: '12345',
      snippet: {
        channelId: 'channel-abcd',
        thumbnails: {}
      },
    )
  end

  def doc
    @doc ||= response_fixture_from_file('youtube-item-page.html', parse_as: :html)
  end

  test "returns provider and type" do
    assert_equal Parser::YoutubeItem.type, 'youtube_item'
  end

  test "does not match invalid URL patterns" do
    invalid_urls = [
      'https://example.com',
      'https://www.youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQm',
      'https://www.youtube.com/user/portadosfundos'
    ]
    
    invalid_urls.each do |url|
      assert_nil Parser::YoutubeItem.match?(url), "Expected #{url} to not match, but it did."
    end
  end

  test "matches known URL patterns, and returns instance on success" do
    valid_urls = [
      # Standard YouTube URLs
      'http://www.youtube.com/watch?v=-wtIMTCHWuI',
      'http://youtube.com/watch?v=-wtIMTCHWuI',
      'http://m.youtube.com/watch?v=-wtIMTCHWuI',
      'https://www.youtube.com/watch?v=lalOy8Mbfdc',
      'https://youtube.com/watch?v=lalOy8Mbfdc',
      'https://m.youtube.com/watch?v=lalOy8Mbfdc',
  
      # URLs with additional parameters and features
      'http://www.youtube.com/watch?v=yZv2daTWRZU&feature=em-uploademail',
      'https://www.youtube.com/watch?v=0zM3nApSvMg#t=0m10s',
      'http://www.youtube.com/watch?v=cKZDdG9FTKY&feature=channel',
      'http://www.youtube.com/watch?v=lalOy8Mbfdc&playnext_from=TL&videos=osPknwzXEas&feature=sub',
  
      # Shortened YouTube URLs
      'http://youtu.be/dQw4w9WgXcQ',
      'https://youtu.be/oTJRivZTMLs?list=PLToa5JuFMsXTNkrLJbRlB--76IAOjRM9b',
  
      # Embedded URLs
      'https://www.youtube.com/embed/0zM3nApSvMg',
      'http://www.youtube.com/embed/lalOy8Mbfdc?rel=0',
  
      # YouTube no-cookie embedded URLs
      'http://www.youtube-nocookie.com/embed/lalOy8Mbfdc?rel=0',  # Added this URL
  
      # Attribution links
      'http://www.youtube.com/attribution_link?a=JdfC0C9V6ZI&u=%2Fwatch%3Fv%3DEhxJLojIE_o%26feature%3Dshare',
  
      # oEmbed URLs
      'https://www.youtube.com/oembed?url=http%3A//www.youtube.com/watch?v%3D-wtIMTCHWuI&format=json',
  
      # Shorts URLs
      'https://www.youtube.com/shorts/j9rZxAF3C0I',
      'https://m.youtube.com/shorts/j9rZxAF3C0I',
  
      # Live URLs
      'https://www.youtube.com/live/8hBmepWUJoc',
  
      # Various video player URLs
      'http://www.youtube.com/v/dQw4w9WgXcQ',
      'https://m.youtube.com/v/-wtIMTCHWuI?version=3&autohide=1'
    ]
  
    valid_urls.each do |url|
      match = Parser::YoutubeItem.match?(url)
      assert_equal true, match.is_a?(Parser::YoutubeItem), "Expected #{url} to match and return a Parser::YoutubeItem instance, but it did not."
    end
  end

  test "should selectively assign YouTube fields to raw api data" do
    data = {}
    # https://github.com/Fullscreen/yt/blob/master/lib/yt/models/video.rb
    # https://github.com/Fullscreen/yt/blob/master/spec/models/video_spec.rb
    fake_video = Yt::Video.new(
      id: '12345',
      snippet: {
        description: 'A cool channel',
        title: 'RubyConf Portugal 2016 - Best Of',
        publishedAt: '2016-11-15T15:20:45Z',
        thumbnails: {
          "default"=>{"url"=> "http://example.com/88x88.jpg"},
          "medium"=>{"url"=> "http://example.com/240x240.jpg"},
        },
        channelTitle: 'Channel1234',
        channelId: 'channel-1234',
      },
    )
    Yt::Video.stub(:new, fake_video) do
      data = Parser::YoutubeItem.new('https://www.youtube.com/watch?v=123456789').parse_data(nil)
    end
    
    assert_equal '12345', data[:raw][:api]['id']
    assert_equal 'A cool channel', data[:raw][:api]['description']
    assert_equal 'RubyConf Portugal 2016 - Best Of', data[:raw][:api]['title']
    assert_equal '2016-11-15T15:20:45Z', data[:raw][:api]['published_at']
    assert_equal 'Channel1234', data[:raw][:api]['channel_title']
    assert_equal 'channel-1234', data[:raw][:api]['channel_id']
    assert_equal "http://example.com/88x88.jpg", data[:raw][:api]['thumbnails']['default']['url']
    assert_equal "http://example.com/240x240.jpg", data[:raw][:api]['thumbnails']['medium']['url']
  end

  test "should assign top-level data items from api data" do
    data = {}
    fake_video = Yt::Video.new(
      id: '12345',
      snippet: {
        description: 'A cool channel',
        title: 'RubyConf Portugal 2016 - Best Of',
        publishedAt: '2016-11-15T15:20:45Z',
        channelTitle: 'Channel1234',
        channelId: 'channel-1234',
        thumbnails: {}
      },
    )
    Yt::Video.stub(:new, fake_video) do
      data = Parser::YoutubeItem.new('https://www.youtube.com/watch?v=123456789').parse_data(nil)
    end
    
    assert_equal '12345', data['external_id']
    assert_equal 'RubyConf Portugal 2016 - Best Of', data['title']
    assert_equal 'A cool channel', data['description']
    assert_equal 'Channel1234', data['username']
    assert_equal 'Channel1234', data['author_name']
    assert_equal '2016-11-15T15:20:45Z', data['published_at']
  end

  test 'assigns highest-res picture information from thumbnails' do
    data = {}
    fake_video = Yt::Video.new(
      id: '12345',
      snippet: {
        thumbnails: {
          "high"=>{"url"=> "http://example.com/88x88.jpg"},
          "maxres"=>{"url"=> "http://example.com/240x240.jpg"},
        },
      },
    )
    Yt::Video.stub(:new, fake_video) do
      data = Parser::YoutubeItem.new('https://www.youtube.com/watch?v=123456789').parse_data(nil)
    end
    
    assert_equal 'http://example.com/240x240.jpg', data['picture']
  end

  # Not sure why we check channel ID and then pull ID from the video here
  test 'assigns valid html when channel ID is present' do
    data = {}
    Yt::Video.stub(:new, minimal_video) do
      data = Parser::YoutubeItem.new('https://www.youtube.com/watch?v=123456789').parse_data(nil)
    end
    
    assert Nokogiri::HTML(data['html']).present?
    assert_match /iframe width='480' height='270' src='\/\/www.youtube.com\/embed\/12345'/, data['html']
  end

  test 'constructs author url when channel ID is present' do
    data = {}
    Yt::Video.stub(:new, minimal_video) do
      data = Parser::YoutubeItem.new('https://www.youtube.com/watch?v=123456789').parse_data(nil)
    end
    
    assert_equal 'https://www.youtube.com/channel/channel-abcd', data['author_url']
  end

  test 'fetches the author picture when channel ID is present' do
    fake_channel = Yt::Channel.new
    fake_channel.stubs(:thumbnail_url).returns('https://example.com/thumbnailurl')
    Yt::Channel.stubs(:new).with(id: 'channel-abcd').returns(fake_channel)

    data = {}
    Yt::Video.stub(:new, minimal_video) do
      data = Parser::YoutubeItem.new('https://www.youtube.com/watch?v=123456789').parse_data(nil)
    end
    
    assert_equal 'https://example.com/thumbnailurl', data['author_picture']
  end

  test 'sets author picture to empty string if an issue with fetching channel info' do
    Yt::Channel.stubs(:new).raises(Yt::Errors::Forbidden)
    
    data = {}
    Yt::Video.stub(:new, minimal_video) do
      data = Parser::YoutubeItem.new('https://www.youtube.com/watch?v=123456789').parse_data(doc)
    end

    assert data['author_picture'].empty?
  end

  test "logs error resulting from invalid authorization and still returns data" do
    Yt::Video.stubs(:new).raises(Yt::Errors::Forbidden)

    data = {}
    sentry_call_count = 0
    arguments_checker = Proc.new do |e|
      sentry_call_count += 1
      assert_equal Yt::Errors::Forbidden, e.class
    end

    PenderSentry.stub(:notify, arguments_checker) do
      data = Parser::YoutubeItem.new('https://www.youtube.com/watch?v=123456789').parse_data(doc)
      assert_equal 1, sentry_call_count
    end
    assert_match /Yt::Errors::Forbidden/, data['raw']['api']['error']['message']
    assert_equal "123456789", data['external_id']
  end

  test "falls back to metadata from doc when data from API not present (error or misconfiguration)" do
    Yt::Video.stubs(:new).raises(Yt::Errors::Forbidden)

    data = Parser::YoutubeItem.new('https://www.youtube.com/watch?v=123456789').parse_data(doc)
    
    assert_equal 'Full Length Freight Trains! 1 Hour of Trains!', data['title']
    assert_match /All aboard!/, data['description']
    assert_match /ytimg.com\/vi\/S49CN57Y58o\/maxresdefault.jpg/, data['picture']
  end

  test "falls back to parsing URL to get external ID" do
    Yt::Video.stubs(:new).raises(Yt::Errors::Forbidden)

    data = Parser::YoutubeItem.new('https://www.youtube.com/watch?v=123456789').parse_data(doc)
    
    assert_equal '123456789', data['external_id']
  end

  test "should not crash when parsing a deleted YouTube video, and should set descriptive attributes" do
    Yt::Video.any_instance.stubs(:snippet).raises(Yt::Errors::NoItems)

    data = Parser::YoutubeItem.new('https://www.youtube.com/watch?v=123456789').parse_data(doc)

    assert_equal 'YouTube', data['username']
    assert_equal 'Full Length Freight Trains! 1 Hour of Trains!', data['title']
    assert_not_equal 'This video is unavailable.', data['description']
    assert data['author_url'].empty?
    assert data['author_picture'].empty?
    assert data['html'].empty?
    assert_nil data[:raw][:api]['thumbnails']
    assert_match(/returned no items/, data[:raw][:api]['error']['message'])
  end

  test "#oembed_url returns URL with the instance URL" do
    oembed_url = Parser::YoutubeItem.new('https://www.youtube.com/watch?v=123456789').oembed_url
    assert_equal 'https://www.youtube.com/oembed?format=json&url=https://www.youtube.com/watch?v=123456789', oembed_url
  end
end
