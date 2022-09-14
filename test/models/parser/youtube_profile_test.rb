require 'test_helper'

class YoutubeProfileIntegrationTest < ActiveSupport::TestCase
  test "should parse YouTube user" do
    m = create_media url: 'https://www.youtube.com/user/portadosfundos'
    data = m.as_json
    assert_equal 'Porta dos Fundos', data['title']
    assert_equal 'portadosfundos', data['username']
    assert_equal 'Porta dos Fundos', data['author_name']
    assert_equal 'profile', data['type']
    assert_equal 'youtube', data['provider']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
    assert_equal data[:raw][:api][:video_count].to_s, data['video_count']
    assert_equal data[:raw][:api][:subscriber_count].to_s, data['subscriber_count']
  end

  test "should store oembed data of a youtube profile using default oembed" do
    RequestHelper.stubs(:get_html).returns(Nokogiri::HTML("<link rel='alternate' type='application/json+oembed' href='https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ' title='Iron Maiden'>"))
    m = create_media url: 'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal 'Iron Maiden', data['oembed']['author_name']
    assert_equal 'Iron Maiden', data['oembed']['title']
    assert_match "http:\/\/www.youtube.com", data['oembed']['provider_url']
    assert_equal "youtube", data['oembed']['provider_name'].downcase
  end
end

class YouTubeProfileUnitTest < ActiveSupport::TestCase
  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  def doc
    @doc ||= response_fixture_from_file('youtube-profile-page.html', parse_as: :html)
  end

  test "returns provider and type" do
    assert_equal Parser::YoutubeProfile.type, 'youtube_profile'
  end

  test "matches known URL patterns, and returns instance on success" do
    assert_nil Parser::YoutubeProfile.match?('https://example.com')
    
    match_one = Parser::YoutubeProfile.match?('https://www.youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQ')
    assert_equal true, match_one.is_a?(Parser::YoutubeProfile)
    match_two = Parser::YoutubeProfile.match?('https://youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQ')
    assert_equal true, match_two.is_a?(Parser::YoutubeProfile)
    match_three = Parser::YoutubeProfile.match?('https://www.youtube.com/user/portadosfundos/')
    assert_equal true, match_three.is_a?(Parser::YoutubeProfile)
  end

  test "should selectively assign YouTube fields to raw api data" do
    # https://github.com/Fullscreen/yt/blob/master/lib/yt/models/channel.rb
    # https://github.com/Fullscreen/yt/blob/master/spec/models/channel_spec.rb
    fake_channel = Yt::Channel.new(
      id: '12345',
      snippet: {
        country: 'US',
        description: 'A cool channel',
        title: 'RubyConf Portugal 2016 - Best Of',
        publishedAt: '2016-11-15T15:20:45Z',
        thumbnails: {
          "default"=>{"url"=> "http://example.com/88x88.jpg"},
          "medium"=>{"url"=> "http://example.com/240x240.jpg"},
        },
      },
      statistics: {
        commentCount: '1',
        subscriberCount: '2',
        videoCount: '3',
        viewCount: '4',
        hiddenSubscriberCount: '100',
      }
    )
    fake_channel.stubs(:playlists).returns([])
    Yt::Channel.stubs(:new).returns(fake_channel)
    
    data = Parser::YoutubeProfile.new('https://www.youtube.com/channel/examplechannel').parse_data(nil)
    
    assert_equal '12345', data[:raw][:api]['id']
    assert_equal '1', data[:raw][:api]['comment_count']
    assert_equal 'US', data[:raw][:api]['country']
    assert_equal 'A cool channel', data[:raw][:api]['description']
    assert_equal 'RubyConf Portugal 2016 - Best Of', data[:raw][:api]['title']
    assert_equal '2016-11-15T15:20:45Z', data[:raw][:api]['published_at']
    assert_equal '2', data[:raw][:api]['subscriber_count']
    assert_equal '3', data[:raw][:api]['video_count']
    assert_equal '4', data[:raw][:api]['view_count']
    assert_equal "http://example.com/88x88.jpg", data[:raw][:api]['thumbnails']['default']['url']
    assert_equal "http://example.com/240x240.jpg", data[:raw][:api]['thumbnails']['medium']['url']
    # Don't assign this value, since not whitelisted
    assert_nil data[:raw][:api]['hidden_subscriber_count']
  end

  test "should assign top-level data items from api data" do
    fake_channel = Yt::Channel.new(
      id: '12345',
      snippet: {
        description: 'A cool channel',
        title: 'RubyConf Portugal 2016 - Best Of',
        publishedAt: '2016-11-15T15:20:45Z',
      },
      statistics: {
        subscriberCount: '2',
        videoCount: '3',
      }
    )
    fake_channel.stubs(:playlists).returns([])
    Yt::Channel.stubs(:new).returns(fake_channel)

    data = Parser::YoutubeProfile.new('https://www.youtube.com/channel/examplechannel').parse_data(nil)
    
    assert_equal '12345', data['external_id']
    assert_equal 'RubyConf Portugal 2016 - Best Of', data['title']
    assert_equal 'A cool channel', data['description']
    assert_equal '2016-11-15T15:20:45Z', data['published_at']
    assert_equal 'RubyConf Portugal 2016 - Best Of', data['author_name']
  end

  test 'assigns highest-res picture information from thumbnails' do
    fake_channel = Yt::Channel.new(
      id: '12345',
      snippet: {
        thumbnails: {
          "default"=>{"url"=> "http://example.com/88x88.jpg"},
          "standard"=>{"url"=> "http://example.com/240x240.jpg"},
        },
      },
      statistics: {}
    )
    fake_channel.stubs(:playlists).returns([])
    Yt::Channel.stubs(:new).returns(fake_channel)

    data = Parser::YoutubeProfile.new('https://www.youtube.com/channel/examplechannel').parse_data(nil)
    
    assert_equal 'http://example.com/240x240.jpg', data['picture']
    assert_equal 'http://example.com/240x240.jpg', data['author_picture']
  end

  test "logs error resulting from invalid authorization and returns default data" do
    Yt::Channel.stubs(:new).raises(Yt::Errors::Forbidden)

    data = {}
    airbrake_call_count = 0
    arguments_checker = Proc.new do |e|
      airbrake_call_count += 1
      assert_equal Yt::Errors::Forbidden, e.class
    end

    PenderAirbrake.stub(:notify, arguments_checker) do
      data = Parser::YoutubeProfile.new('https://www.youtube.com/user/fakeaccount/').parse_data(doc)
      assert_equal 1, airbrake_call_count
    end
    assert_match /Yt::Errors::Forbidden/, data['raw']['api']['error']['message']
    assert_equal "user", data['subtype']
  end

  test "falls back to metadata from doc when data from API not present (error or misconfiguration)" do
    Yt::Channel.stubs(:new).raises(Yt::Errors::Forbidden)

    data = Parser::YoutubeProfile.new('https://www.youtube.com/channel/examplechannel').parse_data(doc)
    
    assert_equal 'examplechannel', data['external_id']
    assert_equal 'CoasterFan2105', data['title']
    assert_match /Quality Railroad Entertainment Since 2002/, data['description']
    assert_match /yt3.ggpht.com\/ytc\/AMLnZu_OnEG7QixZn1lpa0DF61S6SpSOAdoP4vwQUMFv3w/, data['picture']
    assert_match /yt3.ggpht.com\/ytc\/AMLnZu_OnEG7QixZn1lpa0DF61S6SpSOAdoP4vwQUMFv3w/, data['author_picture']
    assert_equal 'CoasterFan2105', data['author_name']
    assert_equal 'coasterfan2105', data['username']
  end

  test "#oembed_url returns URL with the instance URL" do
    oembed_url = Parser::YoutubeProfile.new('https://www.youtube.com/channel/examplechannel').oembed_url
    assert_equal 'https://www.youtube.com/oembed?format=json&url=https://www.youtube.com/channel/examplechannel', oembed_url
  end
end
