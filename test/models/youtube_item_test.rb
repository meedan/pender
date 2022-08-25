require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class YoutubeTest < ActiveSupport::TestCase
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

  test "should parse YouTube channel" do
    api = {"description": "description","title": "","country": "cc",  "publishedAt": "", "id": "1", "comment_count": "0", "thumbnails": ""}
    statistics_data ={"viewCount": "1", "subscriberCount": "1", "hiddenSubscriberCount": false, "videoCount": "1"}
    channel,snippet,statistics_set, pl = "","","",""
    Yt::Channel.stubs(:new).returns(channel)
    channel.stubs(:snippet).returns(snippet);snippet.stubs(:data).returns(api)
    channel.stubs(:id).returns('1')
    channel.stubs(:statistics_set).returns(statistics_set);statistics_set.stubs(:data).returns(statistics_data)
    channel.stubs(:playlists).returns(pl);pl.stubs(:count).returns("")
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
    snippet.unstub(:data);channel.unstub(:id)
    statistics_set.unstub(:data);channel.unstub(:statistics_set)
    pl.unstub(:count);channel.unstub(:playlists);
    channel.unstub(:snippet);Yt::Channel.unstub(:new)
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
    api= {"description": "","title": "RubyConf Portugal 2016 - Best Of", "publishedAt": "2016-11-15T15:20:45Z", "channelTitle": "RubyConf Portugal", "channelId": "UCbcTl4ONoIHwZAllRfU4RvA","id": "mtLxD7r4BZQ", "thumbnails": ""}
    video, snippet = "",""
    Yt::Video.stubs(:new).returns(video)
    video.stubs(:snippet).returns(snippet);snippet.stubs(:data).returns(api)
    url = 'https://www.youtube.com/watch?v=mtLxD7r4BZQ'
    id = Media.get_id url
    m = create_media url: url
    data = m.as_json
    assert_match /^http/, data['author_picture']
    assert_equal data[:raw][:api]['channel_title'], data['username']
    assert_equal data[:raw][:api]['description'], data['description']
    assert_equal data[:raw][:api]['title'], data['title']
    assert_match /#{id}\/picture/, data['picture']
    assert_equal m.html_for_youtube_item, data['html']
    assert_equal data[:raw][:api]['channel_title'], data['author_name']
    assert_equal 'https://www.youtube.com/channel/' + data[:raw][:api]['channel_id'], data['author_url']
    assert_equal data[:raw][:api]['published_at'], data['published_at']
    snippet.unstub(:data); video.unstub(:snippet)
    Yt::Video.unstub(:new)
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
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML("<link rel='alternate' type='application/json+oembed' href='http://www.youtube.com/oembed?format=json&amp;url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DmtLxD7r4BZQ' title='RubyConf Portugal 2016 - Best Of'>"))
    m = create_media url: 'https://www.youtube.com/watch?v=mtLxD7r4BZQ'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal "https:\/\/www.youtube.com\/", data['raw']['oembed']['provider_url']
    assert_equal "YouTube", data['raw']['oembed']['provider_name']
    Media.any_instance.unstub(:get_html)
  end

  test "should store oembed data of a youtube profile" do
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML("<link rel='alternate' type='application/json+oembed' href='https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ' title='Iron Maiden'>"))
    m = create_media url: 'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal 'Iron Maiden', data['oembed']['author_name']
    assert_equal 'Iron Maiden', data['oembed']['title']
    assert_match "http:\/\/www.youtube.com", data['oembed']['provider_url']
    assert_equal "youtube", data['oembed']['provider_name'].downcase
    Media.any_instance.unstub(:get_html)
  end

  test "should get all thumbnails available and set the highest resolution as picture for item" do
    urls = {
      'https://www.youtube.com/watch?v=yyougTzksw8' => { available: ['default', 'high', 'medium'], best: 'high', api: {"description": "description","title": "", "publishedAt": "", "channelTitle": "", "channelId": "","id": "", "thumbnails":{"default": {"url": "https://i.ytimg.com/vi/yyougTzksw8/default.jpg"}, "medium": {"url": "https://i.ytimg.com/vi/yyougTzksw8/mqdefault.jpg"}, "high": {"url": "https://i.ytimg.com/vi/yyougTzksw8/hqdefault.jpg"}}}
      },
      'https://www.youtube.com/watch?v=8Rd5diO16yM' => { available: ['default', 'high', 'medium', 'standard'], best: 'standard', api: {"description": "description","title": "", "publishedAt": "", "channelTitle": "", "channelId": "","id": "", "thumbnails"=>{"default"=>{"url"=>"https://i.ytimg.com/vi/8Rd5diO16yM/default.jpg"}, "medium"=>{"url"=>"https://i.ytimg.com/vi/8Rd5diO16yM/mqdefault.jpg"}, "high"=>{"url"=>"https://i.ytimg.com/vi/8Rd5diO16yM/hqdefault.jpg"}, "standard"=>{"url"=>"https://i.ytimg.com/vi/8Rd5diO16yM/sddefault.jpg"}}}
      } ,
      'https://www.youtube.com/watch?v=WxnN05vOuSM' => { available: ['default', 'high', 'medium', 'standard', 'maxres'], best: 'maxres', api: {"description": "description","title": "", "publishedAt": "", "channelTitle": "", "channelId": "","id": "", "thumbnails"=>{"default"=>{"url"=>"https://i.ytimg.com/vi/WxnN05vOuSM/default.jpg"}, "medium"=>{"url"=>"https://i.ytimg.com/vi/WxnN05vOuSM/mqdefault.jpg"}, "high"=>{"url"=>"https://i.ytimg.com/vi/WxnN05vOuSM/hqdefault.jpg"}, "standard"=>{"url"=>"https://i.ytimg.com/vi/WxnN05vOuSM/sddefault.jpg"}, "maxres"=>{"url"=>"https://i.ytimg.com/vi/WxnN05vOuSM/maxresdefault.jpg"}}}}
    }
    urls.each_pair do |url, thumbnails|
      video = snippet = ""
      Yt::Video.stubs(:new).returns(video)
      video.stubs(:snippet).returns(snippet)
      snippet.stubs(:data).returns(thumbnails[:api])
      id = Media.get_id url
      m = create_media url: url
      data = m.as_json

      assert_match /#{id}\/picture.jpg/, data[:picture]
      saved_img = Pender::Store.current.read(data['picture'].match(/medias\/#{id}\/picture.jpg/)[0])

      open(Media.parse_url(data[:raw][:api]['thumbnails'][thumbnails[:best]]['url'])) do |content|
        Pender::Store.current.store_object("#{id}/parsed-image.jpg", content, 'medias/')
      end
      parsed_img = Pender::Store.current.read("medias/#{id}/parsed-image.jpg")

      assert_equal parsed_img, saved_img
      snippet.unstub(:data);video.unstub(:snippet)
      Yt::Video.unstub(:new)
    end
  end

  test "should get all thumbnails available and set the highest resolution as picture for profile" do
    urls = {
      'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ' => { available: ['default', 'high', 'medium'], best: 'high' },
      'https://www.youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQ' => { available: ['default', 'high', 'medium'], best: 'high' }
    }

    urls.each_pair do |url, thumbnails|
      id = Media.get_id url
      m = create_media url: url
      data = m.as_json
      assert_match /#{id}\/picture.jpg/, data[:picture]
      saved_img = Pender::Store.current.read(data['picture'].match(/medias\/#{id}\/picture.jpg/)[0])

      open(Media.parse_url(data[:raw][:api]['thumbnails'][thumbnails[:best]]['url'])) do |content|
        Pender::Store.current.store_object("#{id}/parsed-image.jpg", content, 'medias/')
      end
      parsed_img = Pender::Store.current.read("medias/#{id}/parsed-image.jpg")

      assert_equal parsed_img, saved_img
    end
  end

  test "should not crash when parsing a deleted YouTube video" do
    url = 'https://www.youtube.com/watch?v=6q_Tcyeq5fk&feature=youtu.be'
    video, snippet = "",""
    Yt::Video.stubs(:new).returns(video)
    video.stubs(:snippet).returns(snippet)
    snippet.stubs(:data).raises(Yt::Errors::NoItems)
    m = create_media url: url
    data = m.as_json
    assert_equal 'YouTube', data['username']
    assert_equal 'Deleted video', data['title']
    assert_equal 'This video is unavailable.', data['description']
    assert_equal '', data['author_url']
    assert_equal '', data['picture']
    assert_equal '', data['html']
    assert_nil data[:raw][:api]['thumbnails']
    assert_match(/returned no items/, data[:raw][:api]['error']['message'])
    snippet.unstub(:data);video.unstub(:snippet)
    Yt::Video.unstub(:new)
  end

  test "should have external id for video" do
    api= {"description": "","title": "", "publishedAt": "2016-11-15T15:20:45Z", "channelTitle": "Iron Maiden", "channelId": "","id": "qMfu1GLVsiM", "thumbnails": ""}
    video, snippet = "",""
    Yt::Video.stubs(:new).returns(video)
    video.stubs(:snippet).returns(snippet);snippet.stubs(:data).returns(api)
    m = create_media url: 'https://www.youtube.com/watch?v=qMfu1GLVsiM'
    data = m.as_json
    assert_not_nil data['external_id']
    snippet.unstub(:data); video.unstub(:snippet)
    Yt::Video.unstub(:new)
  end

  test "should have external id for profile" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML("<meta property='og:url' content='https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ'>"))
    m = create_media url: 'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ'
    data = m.as_json
    assert_equal 'UCaisXKBdNOYqGr2qOXCLchQ', data['external_id']
    Media.any_instance.unstub(:doc)
  end

  test "should get data from metatags when parsing a youtube channel and google_api_key is empty" do
    key = create_api_key application_settings: { config: { google_api_key: '' } }
    m = create_media url: 'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ', key: key
    assert_equal '', PenderConfig.get(:google_api_key)
    data = m.as_json
    assert_equal 'Iron Maiden', data['title']
    assert_match "The request is missing a valid API key.", data['raw']['api']['error']['message']
  end

  test "should get data from metatags when parsing a youtube post and google_api_key is empty" do
    key = create_api_key application_settings: { config: { google_api_key: '' } }
    m = create_media url: 'https://www.youtube.com/watch?v=nO8ZqH5_Fhg', key: key
    assert_equal '', PenderConfig.get(:google_api_key)
    data = m.as_json
    assert_match(/iron maiden/, data['title'].downcase)
    assert_match "The request is missing a valid API key.", data['raw']['api']['error']['message']
  end

  test "should ignore consent page and parse youtube item" do
    consent_page = 'https://consent.youtube.com/m?continue=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fapp%3Ddesktop%26v%3Dp8y8IzeF9u8%26feature%3Dyoutu.be%26ab_channel%3DDra.RobertaLacerda&gl=IE&m=0&pc=yt&uxe=23983172&hl=en&src=1'
    response = ''
    response.stubs(:code).returns('302')
    response.stubs(:header).returns({ 'location' => consent_page })
    Media.any_instance.stubs(:request_media_url).returns(response)
    url = 'https://www.youtube.com/watch?v=bEAdvXRJ9mU'
    m = create_media url: url
    data = m.as_json
    assert_equal 'item', data['type']
    assert_equal 'youtube', data['provider']
    assert_match /Co·Insights: Fostering community collaboration/, data['title']
    assert_match /Co·Insights is a NSF-proposal to create/, data['description']
    assert_equal 'https://www.youtube.com/channel/UCKyn6nCR9fXFhDL-WeeyOzQ', data['author_url']
    assert !data['html'].blank?
    assert_equal 'https://www.youtube.com/watch?v=bEAdvXRJ9mU', m.url
    Media.any_instance.unstub(:request_media_url)
  end
end
