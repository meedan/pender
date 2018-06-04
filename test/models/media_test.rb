require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class MediaTest < ActiveSupport::TestCase
  test "should create media" do
    assert_kind_of Media, create_media
  end

  test "should have URL" do
    m = create_media url: 'http://ca.ios.ba/'
    assert_equal 'http://ca.ios.ba/', m.url
  end

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

  test "should parse Twitter profile" do
    m = create_media url: 'https://twitter.com/caiosba'
    data = m.as_json
    assert_equal 'Caio Almeida', data['title']
    assert_equal '@caiosba', data['username']
    assert_equal 'twitter', data['provider']
    assert_equal 'Caio Almeida', data['author_name']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
    assert_kind_of Hash, data['pictures']
  end

  test "should parse Facebook user profile with identifier" do
    m = create_media url: 'https://www.facebook.com/xico.sa'
    data = m.as_json
    assert_equal 'Xico Sá', data['title']
    assert_equal 'xico.sa', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'user', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse Facebook user profile with numeric id" do
    m = create_media url: 'https://www.facebook.com/profile.php?id=100008161175765&fref=ts'
    data = m.as_json
    assert_equal 'Tico Santa Cruz', data['title']
    assert_equal 'Tico-Santa-Cruz', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'user', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse Facebook page" do
    m = create_media url: 'https://www.facebook.com/ironmaiden/?fref=ts'
    data = m.as_json
    assert_equal 'Iron Maiden', data['title']
    assert_equal 'ironmaiden', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'page', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse Facebook page with numeric id" do
    m = create_media url: 'https://www.facebook.com/pages/Meedan/105510962816034?fref=ts'
    data = m.as_json
    assert_equal 'Meedan', data['title']
    assert_equal 'Meedan', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'page', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should return item as oembed" do
    url = 'https://www.facebook.com/pages/Meedan/105510962816034?fref=ts'
    m = create_media url: url
    data = Media.as_oembed(m.as_json, "http://pender.org/medias.html?url=#{url}", 300, 150)
    assert_equal 'Meedan', data['title']
    assert_equal 'Meedan', data['author_name']
    assert_equal 'https://www.facebook.com/pages/Meedan/105510962816034', data['author_url']
    assert_equal 'facebook', data['provider_name']
    assert_equal 'http://www.facebook.com', data['provider_url']
    assert_equal 300, data['width']
    assert_equal 150, data['height']
    assert_equal '<iframe src="http://pender.org/medias.html?url=https://www.facebook.com/pages/Meedan/105510962816034?fref=ts" width="300" height="150" scrolling="no" border="0" seamless>Not supported</iframe>', data['html']
    assert_not_nil data['thumbnail_url']
  end

  test "should return item as oembed when data is not on cache" do
    url = 'https://www.facebook.com/pages/Meedan/105510962816034?fref=ts'
    m = create_media url: url
    data = Media.as_oembed(nil, "http://pender.org/medias.html?url=#{url}", 300, 150, m)
    assert_equal 'Meedan', data['title']
    assert_equal 'Meedan', data['author_name']
    assert_equal 'https://www.facebook.com/pages/Meedan/105510962816034', data['author_url']
    assert_equal 'facebook', data['provider_name']
    assert_equal 'http://www.facebook.com', data['provider_url']
    assert_equal 300, data['width']
    assert_equal 150, data['height']
    assert_equal '<iframe src="http://pender.org/medias.html?url=https://www.facebook.com/pages/Meedan/105510962816034?fref=ts" width="300" height="150" scrolling="no" border="0" seamless>Not supported</iframe>', data['html']
    assert_not_nil data['thumbnail_url']
  end

  test "should return item as oembed when data is on cache and raw key is missing" do
    url = 'https://www.facebook.com/pages/Meedan/105510962816034?fref=ts'
    m = create_media url: url
    json_data = m.as_json
    json_data.delete('raw')
    data = Media.as_oembed(json_data, "http://pender.org/medias.html?url=#{url}", 300, 150)
    assert_equal 'Meedan', data['title']
    assert_equal 'Meedan', data['author_name']
    assert_equal 'https://www.facebook.com/pages/Meedan/105510962816034', data['author_url']
    assert_equal 'facebook', data['provider_name']
    assert_equal 'http://www.facebook.com', data['provider_url']
    assert_equal 300, data['width']
    assert_equal 150, data['height']
    assert_equal '<iframe src="http://pender.org/medias.html?url=https://www.facebook.com/pages/Meedan/105510962816034?fref=ts" width="300" height="150" scrolling="no" border="0" seamless>Not supported</iframe>', data['html']
    assert_not_nil data['thumbnail_url']
  end

  test "should return item as oembed when the page has oembed url" do
    url = 'https://www.facebook.com/teste637621352/posts/1028416870556238'
    m = create_media url: url
    data = Media.as_oembed(m.as_json, "http://pender.org/medias.html?url=#{url}", 300, 150, m)
    assert_nil data['title']
    assert_equal 'Teste', data['author_name']
    assert_equal 'https://www.facebook.com/teste637621352/', data['author_url']
    assert_equal 'Facebook', data['provider_name']
    assert_equal 'https://www.facebook.com', data['provider_url']
    assert_equal 552, data['width']
    assert data['height'].nil?
  end

  test "should parse Facebook with numeric id" do
    m = create_media url: 'http://facebook.com/513415662050479'
    data = m.as_json
    assert_equal 'https://www.facebook.com/NautilusMag/', data['url']
    assert_equal 'Nautilus Magazine', data['title']
    assert_equal 'NautilusMag', data['username']
    assert_match /Visit us at http:\/\/nautil.us/, data['description']
    assert_equal 'https://www.facebook.com/NautilusMag/', data['author_url']
    assert_match /644661_515192635206115_1479923468/, data['author_picture']
    assert_equal 'Nautilus Magazine', data['author_name']
    assert_not_nil data['picture']
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

  test "should get likes for Facebook profile" do
    m = create_media url: 'https://www.facebook.com/ironmaiden/?fref=ts'
    data = m.as_json
    assert_match /^[0-9]+$/, data['likes'].to_s
  end

  test "should normalize URL" do
    expected = 'http://ca.ios.ba/'
    variations = %w(
      http://ca.ios.ba
      ca.ios.ba
      http://ca.ios.ba:80
      http://ca.ios.ba//
      http://ca.ios.ba/?
      http://ca.ios.ba/#foo
      http://ca.ios.ba/
      http://ca.ios.ba
      http://ca.ios.ba/foo/..
      http://ca.ios.ba/?#
    )
    variations.each do |url|
      media = Media.new(url: url)
      assert_equal expected, media.url
    end

    media = Media.new(url: 'http://ca.ios.ba/a%c3%82/%7Euser?a=b')
    assert_equal 'http://ca.ios.ba/a%C3%82/~user?a=b', media.url

  end

  test "should not normalize URL" do
    urls = %w(
      https://meedan.com/en/
      http://ios.ba/
      http://ca.ios.ba/?foo=bar
    )
    urls.each do |url|
      media = Media.new(url: url)
      assert_equal url, media.url
    end
  end

  test "should parse Arabic Facebook profile" do
    m = create_media url: 'https://www.facebook.com/%D8%A7%D9%84%D9%85%D8%B1%D9%83%D8%B2-%D8%A7%D9%84%D8%AB%D9%82%D8%A7%D9%81%D9%8A-%D8%A7%D9%84%D9%82%D8%A8%D8%B7%D9%8A-%D8%A7%D9%84%D8%A3%D8%B1%D8%AB%D9%88%D8%B0%D9%83%D8%B3%D9%8A-%D8%A8%D8%A7%D9%84%D9%85%D8%A7%D9%86%D9%8A%D8%A7-179240385797/'
    data = m.as_json
    assert_equal 'المركز الثقافي القبطي الأرثوذكسي بالمانيا', data['title']
  end

  test "should throw Pender::ApiLimitReached when Twitter::Error::TooManyRequests is thrown" do
    Twitter::REST::Client.any_instance.stubs(:user).raises(Twitter::Error::TooManyRequests)
    assert_raises Pender::ApiLimitReached do
      m = create_media url: 'https://twitter.com/meedan'
      m.as_json
    end
    Twitter::REST::Client.any_instance.unstub(:user)
  end

  test "should parse shortened URL" do
    m = create_media url: 'http://bit.ly/23qFxCn'
    data = m.as_json
    assert_equal 'https://twitter.com/caiosba', data['url']
    assert_equal 'Caio Almeida', data['title']
    assert_equal '@caiosba', data['username']
    assert_equal 'twitter', data['provider']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
    assert_kind_of Hash, data['pictures']
  end

  test "should parse Arabic URLs" do
    assert_nothing_raised do
      m = create_media url: 'https://www.facebook.com/إدارة-تموين-أبنوب-217188161807938/'
      data = m.as_json
    end
  end

  test "should follow redirection of relative paths" do
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    assert_nothing_raised do
      m = create_media url: 'http://www.almasryalyoum.com/node/517699', request: request
      data = m.as_json
      assert_match /https:\/\/www.almasryalyoum.com\/editor\/details\/968/, data['url']
    end
  end

  test "should parse HTTP-authed URL" do
    m = create_media url: 'https://qa.checkmedia.org/'
    data = m.as_json
    assert_equal 'Check', data['title']
  end

  test "should parse Facebook user profile using user token" do
    variations = %w(
      https://facebook.com/100001147915899
      https://www.facebook.com/100001147915899
    )
    variations.each do |url|
      media = create_media url: url
      data = media.as_json
      assert_equal 'https://www.facebook.com/caiosba', data['url']
      assert_match /Caio Sacramento/, data['title']
      assert_equal 'caiosba', data['username']
      assert_equal 'https://www.facebook.com/caiosba', data['author_url']
      assert_equal 'facebook', data['provider']
      assert_equal 'user', data['subtype']
      assert_not_nil data['description']
      assert_not_nil data['picture']
      assert_not_nil data['published_at']
    end
  end

  test "should parse Facebook user profile using username" do
    m = create_media url: 'https://facebook.com/caiosba'
    data = m.as_json
    assert_equal 'https://www.facebook.com/caiosba', data['url']
    assert_match /Caio Sacramento/, data['title']
    assert_equal 'caiosba', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'user', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse numeric Facebook profile" do
    m = create_media url: 'https://facebook.com/100013581666047'
    data = m.as_json
    assert_equal 'José Silva', data['title']
    assert_equal 'José-Silva', data['username']
  end

  # http://errbit.test.meedan.net/apps/576218088583c6f1ea000231/problems/57a1bf968583c6f1ea000c01
  # https://mantis.meedan.com/view.php?id=4913
  test "should parse numeric Facebook profile 2" do
    url = 'https://www.facebook.com/noha.n.daoud'
    media = Media.new(url: url)
    data = media.as_json
    assert_equal 'Not Found', data['error']['message']
  end

  # http://errbit.test.meedan.net/apps/576218088583c6f1ea000231/problems/57a1bf968583c6f1ea000c01
  # https://mantis.meedan.com/view.php?id=4913
  test "should parse numeric Facebook profile 3" do
    url = 'https://facebook.com/515336093'
    media = Media.new(url: url)
    data = media.as_json
    assert_equal 'Login required to see this profile', data['error']['message']
  end

  test "should parse tweet" do
    m = create_media url: 'https://twitter.com/caiosba/status/742779467521773568'
    data = m.as_json
    assert_equal 'I\'ll be talking in @rubyconfbr this year! More details soon...', data['title']
    assert_equal 'Caio Almeida', data['author_name']
    assert_equal '@caiosba', data['username']
    assert_nil data['picture']
    assert_not_nil data['author_picture']
  end

  test "should throw Pender::ApiLimitReached when Twitter::Error::TooManyRequests is thrown when parsing tweet" do
    Twitter::REST::Client.any_instance.stubs(:status).raises(Twitter::Error::TooManyRequests)
    assert_raises Pender::ApiLimitReached do
      m = create_media url: 'https://twitter.com/caiosba/status/742779467521773568'
      m.as_json
    end
    Twitter::REST::Client.any_instance.unstub(:status)
  end

  test "should create Facebook post from page post URL" do
    m = create_media url: 'https://www.facebook.com/teste637621352/posts/1028416870556238'
    d = m.as_json
    assert_equal '749262715138323_1028416870556238', d['uuid']
    assert_equal "This post is only to test.\n\nEsto es una publicación para testar solamente.", d['text']
    assert_equal '749262715138323', d['user_uuid']
    assert_equal 'Teste', d['author_name']
    assert_equal 0, d['media_count']
    assert_equal '1028416870556238', d['object_id']
    assert_equal '11/2015', d['published_at'].strftime("%m/%Y")
  end

  test "should create Facebook post from page photo URL" do
    m = create_media url: 'https://www.facebook.com/teste637621352/photos/a.754851877912740.1073741826.749262715138323/896869113711015/?type=3'
    d = m.as_json
    assert_equal '749262715138323_896869113711015', d['uuid']
    assert_equal 'This post should be fetched.', d['text']
    assert_equal '749262715138323', d['user_uuid']
    assert_equal 'Teste', d['author_name']
    assert_equal 1, d['media_count']
    assert_equal '896869113711015', d['object_id']
    assert_equal '03/2015', d['published_at'].strftime("%m/%Y")
  end

  test "should create Facebook post from page photo URL 2" do
    m = create_media url: 'https://www.facebook.com/photo.php?fbid=1028424567222135&set=a.1028424563888802.1073741827.749262715138323&type=3'
    d = m.as_json
    assert_equal '749262715138323_1028424567222135', d['uuid']
    assert_equal 'Teste added a new photo.', d['text']
    assert_equal '749262715138323', d['user_uuid']
    assert_equal 'Teste', d['author_name']
    assert_equal 1, d['media_count']
    assert_equal '1028424567222135', d['object_id']
    assert_equal '11/2015', d['published_at'].strftime("%m/%Y")
  end

  test "should create Facebook post from page photos URL" do
    m = create_media url: 'https://www.facebook.com/teste637621352/posts/1028795030518422'
    d = m.as_json
    assert_equal '749262715138323_1028795030518422', d['uuid']
    assert_equal 'This is just a test with many photos.', d['text']
    assert_equal '749262715138323', d['user_uuid']
    assert_equal 'Teste', d['author_name']
    assert_equal 2, d['media_count']
    assert_equal '1028795030518422', d['object_id']
    assert_equal '11/2015', d['published_at'].strftime("%m/%Y")
  end

  test "should create Facebook post from user photos URL" do
    m = create_media url: 'https://www.facebook.com/nanabhay/posts/10156130657385246?pnref=story'
    d = m.as_json
    assert_equal '735450245_10156130657385246', d['uuid']
    assert_equal 'Such a great evening with friends last night. Sultan Sooud Al-Qassemi has an amazing collecting of modern Arab art. It was a visual tour of the history of the region over the last century.', d['text'].strip
    assert_equal '735450245', d['user_uuid']
    assert_equal 'Mohamed Nanabhay', d['author_name']
    assert_equal 4, d['media_count']
    assert_equal '10156130657385246', d['object_id']
    assert_equal '27/10/2015', d['published_at'].strftime("%d/%m/%Y")
  end

  test "should create Facebook post from user photo URL 2" do
    m = create_media url: 'https://www.facebook.com/photo.php?fbid=1195161923843707&set=a.155912291102014.38637.100000497329098&type=3&theater'
    m = create_media url: 'https://www.facebook.com/photo.php?fbid=981302451896323&set=a.155912291102014.38637.100000497329098&type=3&theater'
    d = m.as_json
    assert_equal '100000497329098_981302451896323', d['uuid']
    assert_equal 'Kiko Loureiro added a new photo.', d['text']
    assert_equal '100000497329098', d['user_uuid']
    assert_equal 'Kiko Loureiro', d['author_name']
    assert_not_nil d['picture']
    assert_equal 1, d['media_count']
    assert_equal '981302451896323', d['object_id']
    assert_equal '21/11/2014', d['published_at'].strftime("%d/%m/%Y")
  end

  test "should create Facebook post from user photo URL 3" do
    m = create_media url: 'https://www.facebook.com/photo.php?fbid=10155150801660195&set=p.10155150801660195&type=1&theater'
    d = m.as_json
    assert_equal '10155150801660195_10155150801660195', d['uuid']
    assert_equal '10155150801660195', d['user_uuid']
    assert_equal 'David Marcus', d['author_name']
    assert_equal 1, d['media_count']
    assert_equal '10155150801660195', d['object_id']
    assert_match /always working on ways to make Messenger more useful/, d['text']
  end

  tests = YAML.load_file(File.join(Rails.root, 'test', 'data', 'fbposts.yml'))
  tests.each do |url, text|
    test "should get text from Facebook user post from URL '#{url}'" do
      m = create_media url: url
      assert_equal text, m.as_json['text'].gsub(/\s+/, ' ').strip
    end
  end

  test "should create Facebook post with picture and photos" do
    m = create_media url: 'https://www.facebook.com/teste637621352/posts/1028795030518422'
    d = m.as_json
    assert_match /^https/, d['picture']
    assert_kind_of Array, d['photos']
    assert_equal 2, d['media_count']
    assert_equal 1, d['photos'].size

    m = create_media url: 'https://www.facebook.com/teste637621352/posts/1035783969819528'
    d = m.as_json
    assert_not_nil d['picture']
    assert_match /^https/, d['author_picture']
    assert_kind_of Array, d['photos']
    assert_equal 0, d['media_count']
    assert_equal 1, d['photos'].size

    m = create_media url: 'https://www.facebook.com/johnwlai/posts/10101205465813840?pnref=story'
    d = m.as_json
    assert_match /^https/, d['author_picture']
    assert_match /12715281_10101205465609250_6197101821541617060/, d['picture']
    assert_kind_of Array, d['photos']
    assert_equal 2, d['media_count']
    assert_equal 1, d['photos'].size
  end

  test "should create Facebook post from Arabic user" do
    m = create_media url: 'https://www.facebook.com/ahlam.alialshamsi/posts/108561999277346?pnref=story'
    d = m.as_json
    assert_equal '100003706393630_108561999277346', d['uuid']
    assert_equal '100003706393630', d['user_uuid']
    assert_equal 'Ahlam Ali Al Shāmsi', d['author_name']
    assert_equal 0, d['media_count']
    assert_equal '108561999277346', d['object_id']
    assert_equal 'أنا مواد رافعة الآن الأموال اللازمة لمشروع مؤسسة خيرية، ودعم المحتاجين في غرب أفريقيا مساعدتي لبناء مكانا أفضل للأطفال في أفريقيا', d['text']
  end

  test "should create Facebook post from mobile URL" do
    m = create_media url: 'https://m.facebook.com/photo.php?fbid=981302451896323&set=a.155912291102014.38637.100000497329098&type=3&theater'
    d = m.as_json
    assert_equal '100000497329098_981302451896323', d['uuid']
    assert_equal 'Kiko Loureiro added a new photo.', d['text']
    assert_equal '100000497329098', d['user_uuid']
    assert_equal 'Kiko Loureiro', d['author_name']
    assert_equal 1, d['media_count']
    assert_equal '981302451896323', d['object_id']
    assert_equal '21/11/2014', d['published_at'].strftime("%d/%m/%Y")
  end

  test "should return author_url for Twitter post" do
    m = create_media url: 'https://twitter.com/TheConfMalmo_AR/status/765474989277638657'
    d = m.as_json
    assert_equal 'https://twitter.com/TheConfMalmo_AR', d['author_url']
  end

  test "should return author_name and author_url for Facebook post" do
    m = create_media url: 'https://www.facebook.com/photo.php?fbid=1195161923843707&set=a.155912291102014.38637.100000497329098&type=3&theater'
    d = m.as_json
    assert_equal 'http://facebook.com/100000497329098', d['author_url']
    assert_equal 'Kiko Loureiro', d['author_name']
    assert_match /12144884_1195161923843707_2568663037890130414/, d['picture']
  end

  test "should parse Instagram link" do
    m = create_media url: 'https://www.instagram.com/p/BJwkn34AqtN/'
    d = m.as_json
    assert_equal '@megadeth', d['username']
    assert_equal 'item', d['type']
    assert_equal 'Megadeth', d['author_name']
    assert_not_nil d['picture']
  end

  test "should parse Instagram profile" do
    m = create_media url: 'https://www.instagram.com/megadeth'
    d = m.as_json
    assert_equal '@megadeth', d['username']
    assert_equal 'profile', d['type']
    assert_equal 'megadeth', d['title']
    assert_equal 'megadeth', d['author_name']
    assert_match /^http/, d['picture']
  end

  test "should remove line breaks from Twitter item title" do
    m = create_media url: 'https://twitter.com/realDonaldTrump/status/785148463868735488'
    d = m.as_json
    assert_equal 'LA Times- USC Dornsife Sunday Poll: Donald Trump Retains 2 Point Lead Over Hillary: https://t.co/n05rul4Ycw', d['title']
  end

  test "should parse Facebook photo post url" do
    m = create_media url: 'https://www.facebook.com/quoted.pictures/photos/a.128828073875334.28784.128791873878954/1096134023811396/?type=3&theater'
    d = m.as_json
    assert_equal 'New Quoted Pictures Everyday on Facebook', d['title']
    assert_match(/New Quoted Pictures Everyday added a new photo./, d['description'])
    assert_equal 'quoted.pictures', d['username']
    assert_equal 'New Quoted Pictures Everyday', d['author_name']
  end

  test "should parse Facebook photo post within an album url" do
    m = create_media url: 'https://www.facebook.com/ESCAPE.Egypt/photos/ms.c.eJxNk8d1QzEMBDvyQw79N2ZyaeD7osMIwAZKLGTUViod1qU~;DCBNHcpl8gfMKeR8bz2gH6ABlHRuuHYM6AdywPkEsH~;gqAjxqLAKJtQGZFxw7CzIa6zdF8j1EZJjXRgTzAP43XBa4HfFa1REA2nXugScCi3wN7FZpF5BPtaVDEBqwPNR60O9Lsi0nbDrw3KyaPCVZfqAYiWmZO13YwvSbtygCWeKleh9KEVajW8FfZz32qcUrNgA5wfkA4Xfh004x46d9gdckQt2xR74biSOegwIcoB9OW~_oVIxKML0JWYC0XHvDkdZy0oY5bgjvBAPwdBpRuKE7kZDNGtnTLoCObBYqJJ4Ky5FF1kfh75Gnyl~;Qxqsv.bps.a.1204090389632094.1073742218.423930480981426/1204094906298309/?type=3&theater'
    d = m.as_json
    assert_equal '09/2016', d['published_at'].strftime('%m/%Y')
    assert_equal 'item', d['type']
    assert_equal 'Escape on Facebook', d['title']
    assert_equal 'Escape added a new photo.', d['description']
    assert_match /423930480981426/, d['author_picture']
    assert_equal 1, d['photos'].size
    assert_match /^https:/, d['picture']
    assert_equal '1204094906298309', d['object_id']
  end

  test "should parse Facebook pure text post url" do
    m = create_media url: 'https://www.facebook.com/dina.samak/posts/10153679232246949?pnref=story.unseen-section'
    d = m.as_json
    assert_equal 'Dina Samak on Facebook', d['title']
    assert_not_nil d['description']
    assert_not_nil d['author_picture']
    assert_not_nil d['published_at']
  end

  test "should parse Facebook video url from a page" do
    m = create_media url: 'https://www.facebook.com/144585402276277/videos/1127489833985824'
    d = m.as_json
    assert_equal 'Trent Aric - Meteorologist on Facebook', d['title']
    assert_match /MATTHEW YOU ARE DRUNK...GO HOME!/, d['description']
    assert_equal 'item', d['type']
    assert_not_nil d['picture']
    assert_not_nil d['published_at']
  end

  test "should parse Facebook video url from a page 2" do
    m = create_media url: 'https://www.facebook.com/democrats/videos/10154268929856943'
    d = m.as_json
    assert_equal 'Democratic Party on Facebook', d['title']
    assert_match /On National Voter Registration Day/, d['description']
    assert_equal 'item', d['type']
    assert_not_nil d['picture']
    assert_not_nil d['published_at']
  end

  test "should parse Facebook video url from a profile" do
    m = create_media url: 'https://www.facebook.com/edwinscott143/videos/vb.737361619/10154242961741620/?type=2&theater'
    d = m.as_json
    assert_equal 'Eddie Scott on Facebook', d['title']
    assert_equal 'item', d['type']
    assert_match /14146479_10154242963196620_407850789/, d['picture']
    assert_not_nil d['author_picture']
    assert_not_nil d['published_at']
  end

  test "should parse Facebook event url" do
    m = create_media url: 'https://www.facebook.com/events/1090503577698748'
    d = m.as_json
    assert_equal 'Nancy Ajram on Facebook', d['title']
    assert_not_nil d['description']
    assert_nil d['picture']
    assert_not_nil d['published_at']
    assert_match /1090503577698748/, d['author_picture']
  end

  test "should parse album post with a permalink" do
    m = create_media url: 'https://www.facebook.com/permalink.php?story_fbid=10154534111016407&id=54212446406'
    d = m.as_json
    assert_equal 'Mariano Rajoy Brey on Facebook', d['title']
    assert_equal 'item', d['type']
    assert_equal '10154534111016407', d['object_id']
    assert_match /54212446406/, d['author_picture']
    assert_match /14543767_10154534111016407_5167486558738906371/, d['picture']
    assert_not_nil d['published_at']
  end

  test "should parse Facebook gif photo url" do
    m = create_media url: 'https://www.facebook.com/quoted.pictures/posts/1095740107184121'
    d = m.as_json
    assert_equal 'New Quoted Pictures Everyday on Facebook', d['title']
    assert_not_nil d['description']
    assert_match /giphy.gif/, d['photos'].first
  end

  test "should parse twitter metatags" do
    m = create_media url: 'https://www.flickr.com/photos/bees/2341623661'
    d = m.as_json
    assert_equal 'ZB8T0193', d['title']
    assert_match /Explore .* photos on Flickr!/, d['description']
    assert_equal '', d['published_at']
    assert_equal 'https://c2.staticflickr.com/4/3123/2341623661_7c99f48bbf_b.jpg', d['picture']
    assert_equal 'https://www.flickr.com/photos/bees/', d['author_url']
  end

  test "should parse twitter metatags 2" do
    m = create_media url: 'https://www.hongkongfp.com/2017/03/08/top-officials-suing-defamation-may-give-perception-bullying-says-chief-exec-candidate-woo/'
    d = m.as_json
    assert_match(/Hong Kong Free Press/, d['title'])
    assert_equal 'https://www.hongkongfp.com/wp-content/uploads/2017/03/2017-03-06_11-45-23.jpg', d['picture']
    assert_match(/Chief executive candidate Woo Kw-hing/, d['description'])
    assert_equal '@krislc', d['username']
    assert_equal 'https://twitter.com/krislc', d['author_url']
  end

  test "should parse opengraph metatags" do
    m = create_media url: 'http://hacktoon.com/nerdson/2016/poker-planning'
    d = m.as_json
    assert_equal 'Poker planning | Hacktoon!', d['title']
    assert_equal 'Programming comics and digital culture', d['description']
    assert_equal '', d['published_at']
    assert_equal 'Karlisson M. Bezerra', d['username']
    assert_equal 'https://hacktoon.com/static/img/facebook-image.png', d['picture']
    assert_equal 'https://hacktoon.com', d['author_url']
  end

  test "should parse meta tags as fallback" do
    Media.any_instance.unstub(:archive_to_screenshot)
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    m = create_media url: 'https://xkcd.com/1479', request: request
    d = m.as_json
    assert_equal 'xkcd: Troubleshooting', d['title']
    assert_equal '', d['description']
    assert_equal '', d['published_at']
    assert_equal '', d['username']
    assert_equal 'https://xkcd.com', d['author_url']

    filename = Digest::MD5.hexdigest(m.url.parameterize) + '.png'
    path = File.join(Rails.root, 'public', 'screenshots', filename)
    assert File.exists?(path)
    assert_match /\/screenshots\/#{filename}$/, d['picture']
  end

  test "should parse meta tags as fallback 2" do
    Media.any_instance.unstub(:archive_to_screenshot)
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    m = create_media url: 'http://ca.ios.ba/', request: request
    d = m.as_json
    assert_equal 'CaioSBA', d['title']
    assert_equal 'Personal website of Caio Sacramento de Britto Almeida', d['description']
    assert_equal '', d['published_at']
    assert_equal '', d['username']
    assert_equal 'http://ca.ios.ba', d['author_url']

    filename = Digest::MD5.hexdigest(m.url.parameterize) + '.png'
    path = File.join(Rails.root, 'public', 'screenshots', filename)
    assert File.exists?(path)
    assert_match /\/screenshots\/#{filename}$/, d['screenshot']
  end

  test "should parse Facebook photo on page album" do
    m = create_media url: 'https://www.facebook.com/scmp/videos/vb.355665009819/10154584426664820/?type=2&theater'
    d = m.as_json
    assert_equal 'South China Morning Post on Facebook', d['title']
    assert_match /SCMP #FacebookLive/, d['description']
    assert_equal 'scmp', d['username']
    assert_match /355665009819/, d['author_picture']
    assert_match /14645700_10154584445939820_3787909207995449344/, d['picture']
    assert_equal 'http://facebook.com/355665009819', d['author_url']
    assert_not_nil d['published_at']
  end

  test "should not overwrite metatags with nil" do
    m = create_media url: 'http://meedan.com'
    m.expects(:get_opengraph_metadata).returns({author_url: nil})
    m.expects(:get_twitter_metadata).returns({author_url: nil})
    m.expects(:get_oembed_metadata).returns({})
    m.expects(:get_basic_metadata).returns({description: "", title: "Meedan Checkdesk", username: "Tom", published_at: "", author_url: "https://meedan.checkdesk.org", picture: 'meedan.png'})
    d = m.as_json
    assert_equal 'Meedan Checkdesk', d['title']
    assert_equal 'Tom', d['username']
    assert_not_nil d['description']
    assert_not_nil d['picture']
    assert_not_nil d['published_at']
    assert_equal 'https://meedan.checkdesk.org', d['author_url']
  end

  test "should parse meta tags 2" do
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    m = create_media url: 'https://meedan.com/en/check/', request: request
    d = m.as_json
    assert_equal 'Check', d['title']
    assert_match(/Verify digital media consistently and openly/, d['description'])
    assert_equal '', d['published_at']
    assert_equal '', d['username']
    assert_equal 'https://meedan.com/en/check/', m.url
    assert_equal 'https://meedan.com', d['author_url']
    assert_not_nil d['picture']
  end

  test "should parse valid link with blank spaces" do
    m = create_media url: ' https://twitter.com/anxiaostudio/status/788095322496995328 '
    d = m.as_json
    assert_equal 'https://twitter.com/anxiaostudio/status/788095322496995328', m.url
    assert_equal '@andybudd @jennifermjones cc @blinkpopshift', d['title']
    assert_equal '@andybudd @jennifermjones cc @blinkpopshift', d['description']
    assert_not_nil d['published_at']
    assert_equal '@anxiaostudio', d['username']
    assert_equal 'https://twitter.com/anxiaostudio', d['author_url']
    assert_nil d['picture']
    assert_not_nil d['author_picture']
  end

  test "should get canonical URL parsed from html tags" do
    media1 = create_media url: 'https://twitter.com/lila_engel/status/783423627383504896?ref_src=twsrc%5Etfw'
    media2 = create_media url: 'https://twitter.com/lila_engel/status/783423627383504896'
    assert_equal media1.url, media2.url
  end

  test "should get canonical URL parsed from html tags 2" do
    media1 = create_media url: 'https://www.instagram.com/p/BK4YliEAatH/?taken-by=anxiaostudio'
    media2 = create_media url: 'https://www.instagram.com/p/BK4YliEAatH/'
    assert_equal media1.url, media2.url
  end

  test "should get canonical URL parsed from html tags 3" do
    media1 = create_media url: 'http://mulher30.com.br/2016/08/bom-dia-2.html'
    media2 = create_media url: 'http://mulher30.com.br/?p=6704&fake=123'
    assert_equal media1.url, media2.url
  end

  test "should return success to any valid link" do
    m = create_media url: 'https://www.reddit.com/r/Art/comments/58a8kp/emotions_language_youngjoo_namgung_ai_livesurface/'
    d = m.as_json
    assert_match /emotion's language, Youngjoo Namgung/, d['title']
    assert_match /.* (points|votes) and .* so far on reddit/, d['description']
    assert_equal '', d['published_at']
    assert_equal '', d['username']
    assert_equal 'https://www.reddit.com', d['author_url']
    assert_match /https:\/\/i.redditmedia.com\/Y5ijHvqlYPzBHOAxWEf4PgcXQWwo2JSLeF7gZ5ZXl5E.png/, d['picture']
  end

  test "should return success to any valid link 2" do
    m = create_media url: 'http://www.youm7.com/story/2016/7/6/بالصور-مياه-الشرب-بالإسماعيلية-تواصل-عملها-لحل-مشكلة-طفح-الصرف/2790125'
    d = m.as_json
    assert_equal 'بالصور.. مياه الشرب بالإسماعيلية تواصل عملها لحل مشكلة طفح الصرف ببعض الشوارع - اليوم السابع', d['title']
    assert_match /واصلت غرفة عمليات شركة/, d['description']
    assert_not_nil d['published_at']
    assert_equal '', d['username']
    assert_equal 'http://www.youm7.com', d['author_url']
    assert_equal 'https://img.youm7.com/large/72016619556415g.jpg', d['picture']
  end

  test "should store the picture address" do
    Media.any_instance.unstub(:archive_to_screenshot)
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    m = create_media url: 'http://xkcd.com/448/', request: request
    d = m.as_json
    assert_equal 'xkcd: Good Morning', d['title']
    assert_equal '', d['description']
    assert_equal '', d['published_at']
    assert_equal '', d['username']
    assert_equal 'https://xkcd.com', d['author_url']
    filename = Digest::MD5.hexdigest(m.url.parameterize) + '.png'
    assert_match /\/screenshots\/#{filename}$/, d['screenshot']
  end

  test "should get relative canonical URL parsed from html tags" do
    m = create_media url: 'http://meedan.com'
    d = m.as_json
    assert_equal 'https://meedan.com/en/', m.url
    assert_equal 'Meedan', d['title']
    assert_match /team of designers, technologists and journalists/, d['description']
    assert_equal '', d['published_at']
    assert_equal '', d['username']
    assert_equal 'https://meedan.com', d['author_url']
    assert_equal 'http://meedan.com/images/logos/meedan-logo-600@2x.png', d['picture']
  end

  test "should get canonical URL parsed from facebook html" do
    media1 = create_media url: 'https://www.facebook.com/photo.php?fbid=1195161923843707&set=a.155912291102014.38637.100000497329098&type=3&theater'
    media2 = create_media url: 'https://www.facebook.com/photo.php?fbid=1195161923843707&set=a.155912291102014.38637.100000497329098&type=3'
    media1.as_json
    media2.as_json
    assert_equal media2.url, media1.url
  end

  test "should get canonical URL parsed from facebook html when it is relative" do
    media1 = create_media url: 'https://www.facebook.com/dina.samak/posts/10153679232246949?pnref=story.unseen-section'
    media2 = create_media url: 'https://www.facebook.com/dina.samak/posts/10153679232246949'
    media1.as_json
    media2.as_json
    assert_equal media2.url, media1.url
  end

  test "should get canonical URL parsed from facebook html when it is a page" do
    media1 = create_media url: 'https://www.facebook.com/CyrineOfficialPage/posts/10154332542247479?pnref=story.unseen-section'
    media2 = create_media url: 'https://www.facebook.com/CyrineOfficialPage/posts/10154332542247479'
    media1.as_json
    media2.as_json
    assert_equal media2.url, media1.url
  end

  test "should get canonical URL from facebook object" do
    expected = 'https://www.facebook.com/democrats/videos/10154268929856943/'
    variations = %w(
      https://www.facebook.com/democrats/videos/10154268929856943
      https://www.facebook.com/democrats/posts/10154268929856943/
    )
    variations.each do |url|
      media = Media.new(url: url)
      media.as_json
      assert_equal expected, media.url
    end
  end

  test "should get canonical URL from facebook object 2" do
    media = Media.new(url: 'https://www.facebook.com/permalink.php?story_fbid=10154534111016407&id=54212446406')
    media.as_json({ force: 1 })
    assert_equal 'https://www.facebook.com/media/set/?set=a.10154534110871407.1073742048.54212446406&type=3', media.url
  end

  test "should get canonical URL from facebook object 3" do
    expected = 'https://www.facebook.com/media/set/?set=a.10154534110871407.1073742048.54212446406&type=3'
    variations = %w(
      https://www.facebook.com/54212446406/photos/a.10154534110871407.1073742048.54212446406/10154534111016407/?type=3
      https://www.facebook.com/54212446406/photos/a.10154534110871407.1073742048.54212446406/10154534111016407?type=3
    )
    variations.each do |url|
      media = Media.new(url: url)
      media.as_json({ force: 1 })
      assert_equal expected, media.url
    end
  end

  test "should parse facebook url with a photo album" do
    expected = {
      url: 'https://www.facebook.com/Classic.mou/photos/a.136991166478555.1073741828.136985363145802/613639175480416/?type=3',
      title: 'Classic on Facebook',
      username: 'Classic.mou',
      author_name: 'Classic',
      author_url: 'http://facebook.com/136985363145802',
      author_picture: 'https://graph.facebook.com/136985363145802/picture'
    }.with_indifferent_access

    variations = %w(
      https://www.facebook.com/Classic.mou/photos/pcb.613639338813733/613639175480416/?type=3&theater
      https://www.facebook.com/Classic.mou/photos/pcb.613639338813733/613639175480416/
    )
    variations.each do |url|
      media = Media.new(url: url)
      data = media.as_json
      expected.each do |key, value|
        assert_equal value, data[key]
        assert_match /613639175480416_2497518582358260577/, data[:picture]
        assert_match /Classic added a new photo/, data[:description]
      end
    end
  end

  test "should parse tweet url with special chars" do
    m = create_media url: 'http://twitter.com/#!/salmaeldaly/status/45532711472992256'
    data = m.as_json
    assert_equal 'https://twitter.com/salmaeldaly/status/45532711472992256', m.url
    assert_equal ['twitter', 'item'], [m.provider, m.type]
    assert_equal 'وعشان نبقى على بياض أنا مش موافقة على فكرة الاعتصام اللي في التحرير، بس دة حقهم وأنا بدافع عن حقهم الشرعي، بغض النظر عن اختلافي معهم', data['title']
    assert_equal data['title'], data['description']
    assert_not_nil data['published_at']
    assert_equal '@salmaeldaly', data['username']
    assert_equal 'https://twitter.com/salmaeldaly', data['author_url']
    assert_nil data['picture']
    assert_not_nil data['author_picture']
  end

  test "should parse Facebook live post from mobile URL" do
    m = create_media url: 'https://m.facebook.com/story.php?story_fbid=10154584426664820&id=355665009819%C2%ACif_t=live_video%C2%ACif_id=1476846578702256&ref=bookmarks'
    data = m.as_json
    assert_equal 'https://www.facebook.com/scmp/videos/10154584426664820/', m.url
    assert_equal 'South China Morning Post on Facebook', data['title']
    assert_match /SCMP #FacebookLive amid chaotic scenes in #HongKong Legco/, data['description']
    assert_not_nil data['published_at']
    assert_equal 'scmp', data['username']
    assert_equal 'http://facebook.com/355665009819', data['author_url']
    assert_equal 'https://graph.facebook.com/355665009819/picture', data['author_picture']
    assert_match /14645700_10154584445939820_3787909207995449344/, data['picture']
  end

  test "should parse Facebook live post" do
    m = create_media url: 'https://www.facebook.com/cbcnews/videos/10154783484119604/'
    data = m.as_json
    assert_equal 'https://www.facebook.com/cbcnews/videos/10154783484119604/', m.url
    assert_equal 'CBC News on Facebook', data['title']
    assert_equal 'Live now: This is the National for Monday, Oct. 31, 2016.', data['description']
    assert_not_nil data['published_at']
    assert_equal 'cbcnews', data['username']
    assert_equal 'http://facebook.com/5823419603', data['author_url']
    assert_equal 'https://graph.facebook.com/5823419603/picture', data['author_picture']
    assert_match /14926650_10154783812779604_1342878673929240576/, data['picture']
  end

  test "should parse Facebook removed live post" do
    m = create_media url: 'https://www.facebook.com/teste637621352/posts/1538843716180215/'
    data = m.as_json
    assert_equal 'https://www.facebook.com/teste637621352/posts/1538843716180215', m.url
    assert_equal 'Not Identified on Facebook', data['title']
    assert_equal '', data['description']
    assert_equal '', data['published_at']
    assert_equal 'teste637621352', data['username']
    assert_equal 'http://facebook.com/749262715138323', data['author_url']
    assert_equal 'https://graph.facebook.com/749262715138323/picture', data['author_picture']
  end

  test "should parse Facebook livemap" do
    variations = %w(
      https://www.facebook.com/livemap/#@-12.991858482361014,-38.521747589110994,4z
      https://www.facebook.com/live/map/#@37.777053833008,-122.41587829590001,4z
      https://www.facebook.com/live/discover/map/#@37.777053833008,-122.41587829590001,4z
    )

    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')

    variations.each do |url|
      m = create_media url: url, request: request
      data = m.as_json
      assert_equal 'Facebook Live Map on Facebook', data['title']
      assert_equal 'Explore live videos from around the world.', data['description']
      assert_not_nil data['published_at']
      assert_equal 'Facebook Live Map', data['username']
      assert_equal 'http://facebook.com/', data['author_url']
      assert_equal '', data['author_picture']
      assert_nil data['picture']
      assert_equal 'https://www.facebook.com/live/discover/map/', m.url
    end
  end

  test "should parse Facebook event post" do
    m = create_media url: 'https://www.facebook.com/events/364677040588691/permalink/376287682760960/?ref=1&action_history=null'
    data = m.as_json
    assert_equal 'https://www.facebook.com/events/364677040588691/permalink/376287682760960?ref=1&action_history=null', m.url
    assert_not_nil data['published_at']
    assert_match /#{data['user_uuid']}/, data['author_url']
    assert_match /^https:/, data['picture']
    assert_equal 'Zawya on Facebook', data['title']
    assert_match /لختامي من فيلم/, data['description']
    assert_equal 'Zawya', data['username']
  end

  test "should parse Facebook event post 2" do
    m = create_media url: 'https://www.facebook.com/events/364677040588691/permalink/379973812392347/?ref=1&action_history=null'
    data = m.as_json
    assert_equal 'https://www.facebook.com/events/364677040588691/permalink/379973812392347?ref=1&action_history=null', m.url
    assert_equal 'Zawya on Facebook', data['title']
    assert_match /يقول فارس لرزق أنه/, data['description']
    assert_not_nil data['published_at']
    assert_equal 'Zawya', data['username']
    assert_match /#{data['user_uuid']}/, data['author_url']
    assert_match /#{data['user_uuid']}/, data['author_picture']
    assert_not_nil data['picture']
  end

  test "should parse url with arabic chars" do
    m = create_media url: 'http://www.aljazeera.net/news/arabic/2016/10/19/تحذيرات-أممية-من-احتمال-نزوح-مليون-مدني-من-الموصل'
    d = m.as_json
    assert_equal 'تحذيرات أممية من احتمال نزوح مليون مدني من الموصل', d['title']
    assert_equal 'عبرت الأمم المتحدة عن قلقها البالغ على سلامة 1.5 مليون شخص بالموصل، محذرة من احتمال نزوح مليون منهم، وقالت إن أكثر من 900 نازح فروا إلى سوريا بأول موجة نزوح.', d['description']
    assert_equal '', d['published_at']
    assert_equal '', d['username']
    assert_match /^https?:\/\/www\.aljazeera\.net$/, d['author_url']
    assert_match /^https?:\/\/www\.aljazeera\.net\/file\/GetImageCustom\/f1dbce3b-5a2f-4edb-89c5-43e6ba6810c6\/1200\/630$/, d['picture']
  end

  test "should parse url with already encoded chars" do
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    m = create_media url: 'http://www.aljazeera.net/news/arabic/2016/10/19/%D8%AA%D8%AD%D8%B0%D9%8A%D8%B1%D8%A7%D8%AA-%D8%A3%D9%85%D9%85%D9%8A%D8%A9-%D9%85%D9%86-%D8%A7%D8%AD%D8%AA%D9%85%D8%A7%D9%84-%D9%86%D8%B2%D9%88%D8%AD-%D9%85%D9%84%D9%8A%D9%88%D9%86-%D9%85%D8%AF%D9%86%D9%8A-%D9%85%D9%86-%D8%A7%D9%84%D9%85%D9%88%D8%B5%D9%84'
    d = m.as_json
    assert_equal 'تحذيرات أممية من احتمال نزوح مليون مدني من الموصل', d['title']
    assert_equal 'عبرت الأمم المتحدة عن قلقها البالغ على سلامة 1.5 مليون شخص بالموصل، محذرة من احتمال نزوح مليون منهم، وقالت إن أكثر من 900 نازح فروا إلى سوريا بأول موجة نزوح.', d['description']
    assert_equal '', d['published_at']
    assert_equal '', d['username']
    assert_match /^https?:\/\/www\.aljazeera\.net$/, d['author_url']
    assert_match /^https?:\/\/www\.aljazeera\.net\/file\/GetImageCustom\/f1dbce3b-5a2f-4edb-89c5-43e6ba6810c6\/1200\/630$/, d['picture']
  end

  test "should parse url 1" do
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    m = create_media url: 'http://www.theatlantic.com/magazine/archive/2016/11/war-goes-viral/501125/', request: request
    d = m.as_json
    assert_equal 'War Goes Viral', d['title']
    assert_equal 'How social media is being weaponized across the world', d['description']
    assert_equal '', d['published_at']
    assert_equal 'Emerson T. Brooking and P. W. Singer', d['username']
    assert_equal 'https://www.theatlantic.com', d['author_url']
    assert_match /https:\/\/cdn\.theatlantic\.com\/assets\/media\/img\/2016\/10\/WEL_Singer_SocialWar_opener_ALT\/facebook\.jpg/, d['picture']
  end

  test "should parse url 2" do
    m = create_media url: 'https://www.theguardian.com/politics/2016/oct/19/larry-sanders-on-brother-bernie-and-why-tony-blair-was-destructive'
    d = m.as_json
    assert_equal 'Larry Sanders on brother Bernie and why Tony Blair was ‘destructive’', d['title']
    assert_match /The Green party candidate, who is fighting the byelection in David Cameron’s old seat/, d['description']
    assert_match /2016-10/, d['published_at']
    assert_equal '@zoesqwilliams', d['username']
    assert_equal 'https://twitter.com/zoesqwilliams', d['author_url']
    assert_match /https:\/\/i.guim.co.uk\/img\/media\/d43d8d320520d7f287adab71fd3a1d337baf7516\/0_945_3850_2310\/master\/3850.jpg/, d['picture']
  end

  test "should parse url 3" do
    m = create_media url: 'https://almanassa.com/ar/story/3164'
    d = m.as_json
    assert_equal 'تسلسل زمني| تحرير الموصل: أسئلة الصراع الإقليمي تنتظر الإجابة.. أو الانفجار', d['title']
    assert_match /مرت الأيام التي تلت محاولة اغتيال العبادي/, d['description']
    assert_equal '', d['published_at']
    assert !d['author_name'].blank?
    assert_match /https:\/\/almanassa.com/, d['author_url']
    assert_match /\/\/almanassa.com\/sites\/default\/files\/irq_367110792_1469895703-bicubic\.jpg/, d['picture']
  end

  test "should parse url 4" do
    m = create_media url: 'https://www.facebook.com/ironmaiden/videos/vb.172685102050/10154577999342051/?type=2&theater'
    d = m.as_json
    assert_equal 'Iron Maiden on Facebook', d['title']
    assert_equal 'Tailgunner! #Lancaster #Aircraft #Plane #WW2 #IronMaiden #TheBookOfSoulsWorldTour #Canada #Toronto #CWHM', d['description']
    assert_not_nil d['published_at']
    assert_equal 'ironmaiden', d['username']
    assert_equal 'Iron Maiden', d['author_name']
    assert_equal 'http://facebook.com/172685102050', d['author_url']
    assert_equal 'https://graph.facebook.com/172685102050/picture', d['author_picture']
    assert_match /20131236_10154578000322051_2916467421743153152/, d['picture']
  end

  test "should parse bridge url" do
    m = create_media url: 'https://speakbridge.io/medias/embed/viber/1/403'
    d = m.as_json
    assert_equal 'Translations of Viberهل يحتوي هذا الطعام على لحم الخنزير؟', d['title']
    assert_equal 'هل يحتوي هذا الطعام على لحم الخنزير؟', d['description']
    assert_not_nil d['published_at']
    assert_equal '', d['username']
    assert_equal '', d['author_url']
    assert_equal 'https://speakbridge.io/medias/embed/viber/1/403.png', d['picture']
  end

  test "should parse facebook url without identified pattern as item" do
    m = create_media url: 'https://www.facebook.com/Bimbo.Memories/photos/pb.235404669918505.-2207520000.1481570271./1051597428299221/?type=3&theater'
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal 'Bimbo Memories on Facebook', d['title']
    assert_not_nil d['description']
    assert_not_nil d['published_at']
    assert_equal 'Bimbo Memories', d['author_name']
    assert_equal 'Bimbo.Memories', d['username']
    assert_equal 'http://facebook.com/235404669918505', d['author_url']
    assert_equal 'https://graph.facebook.com/235404669918505/picture', d['author_picture']
    assert_match /15400507_1051597428299221_6315842220063966332/, d['picture']
  end

  test "should parse facebook url without identified pattern as item 2" do
    m = create_media url: 'https://www.facebook.com/Classic.mou/photos/pb.136985363145802.-2207520000.1481570401./640132509497749/?type=3&theater'
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal 'Classic on Facebook', d['title']
    assert_match /سعاد/, d['description']
    assert_not_nil d['published_at']
    assert_equal 'Classic', d['author_name']
    assert_equal 'Classic.mou', d['username']
    assert_equal 'http://facebook.com/136985363145802', d['author_url']
    assert_equal 'https://graph.facebook.com/136985363145802/picture', d['author_picture']
    assert_match /640132509497749_4281523565478374345/, d['picture']
  end

  test "should return author picture" do
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    m = create_media url: 'http://github.com', request: request
    d = m.as_json
    assert_match /github-logo.png/, d['author_picture']
  end

  test "should return Facebook author picture" do
    m = create_media url: 'https://www.facebook.com/ironmaiden/photos/a.406269382050.189128.172685102050/10154015223857051/?type=3&theater'
    d = m.as_json
    assert_match /^http/, d['author_picture']
  end

  test "should return Twitter author picture" do
    m = create_media url: 'https://twitter.com/meedan/status/773947372527288320'
    d = m.as_json
    assert_match /^http/, d['author_picture']
  end

  test "should return Instagram author picture" do
    m = create_media url: 'https://www.instagram.com/p/BOXV2-7BPAu'
    d = m.as_json
    assert_match /^http/, d['author_picture']
  end

  test "should return YouTube fields" do
    m = create_media url: 'https://www.youtube.com/watch?v=mtLxD7r4BZQ'
    data = m.as_json
    assert_match /^http/, data['author_picture']
    assert_equal data[:raw][:api]['channel_title'], data['username']
    assert_equal data[:raw][:api]['description'], data['description']
    assert_equal data[:raw][:api]['title'], data['title']
    assert_equal data[:raw][:api]['thumbnail_url'], data['picture']
    assert_equal data[:raw][:api]['embed_html'], data['html']
    assert_equal data[:raw][:api]['channel_title'], data['author_name']
    assert_equal 'https://www.youtube.com/channel/' + data[:raw][:api]['channel_id'], data['author_url']
    assert_equal data[:raw][:api]['published_at'], data['published_at']
  end

  test "should handle connection reset by peer error" do
    url = 'https://br.yahoo.com/'
    parsed_url = Media.parse_url(url)
    OpenURI.stubs(:open_uri).raises(Errno::ECONNRESET)
    m = create_media url: url
    assert_nothing_raised do
      m.send(:get_html, Media.send(:html_options, m.url))
    end
    OpenURI.unstub(:open_uri)
  end

  test "should parse ca yahoo site" do
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    m = create_media url: 'https://ca.yahoo.com/', request: request
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal 'page', d['provider']
    assert_equal 'Yahoo', d['title']
    assert_not_nil d['description']
    assert_not_nil d['published_at']
    assert_equal '', d['username']
    assert_equal 'https://ca.yahoo.com', d['author_url']
    assert_equal 'Yahoo', d['author_name']
    assert_not_nil d['picture']
    assert_nil d['error']
  end

  test "should parse us yahoo site" do
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    m = create_media url: 'https://www.yahoo.com/', request: request
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal 'page', d['provider']
    assert_equal 'Yahoo', d['title']
    assert_not_nil d['description']
    assert_not_nil d['published_at']
    assert_equal '', d['username']
    assert_not_nil d['author_url']
    assert_equal 'Yahoo', d['author_name']
    assert_not_nil d['picture']
    assert_nil d['error']
  end

  test "should return absolute url" do
    m = create_media url: 'https://www.test.com'
    paths = {
      nil => m.url,
      '' => m.url,
      'http://www.test.bli' => 'http://www.test.bli',
      '//www.test.bli' => 'https://www.test.bli',
      '/example' => 'https://www.test.com/example'
    }
    paths.each do |path, expected|
      returned = m.send(:absolute_url, path)
      assert_equal expected, returned
    end
  end

  test "should redirect Facebook URL" do
    m = create_media url: 'https://www.facebook.com/profile.php?id=100001147915899'
    d = m.as_json
    assert_equal 'caiosba', d['username']
    assert_equal 'https://www.facebook.com/caiosba', d['url']
  end

  test "should parse facebook page item" do
    m = create_media url: 'https://www.facebook.com/dina.hawary/posts/10158416884740321'
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal 'facebook', d['provider']
    assert_equal 'Dina El Hawary on Facebook', d['title']
    assert_match /ربنا يزيدهن فوق القوة قوة/, d['description']
    assert_not_nil d['published_at']
    assert_equal 'Dina El Hawary', d['author_name']
    assert_equal 'dina.hawary', d['username']
    assert_equal 'http://facebook.com/813705320', d['author_url']
    assert_equal 'https://graph.facebook.com/813705320/picture', d['author_picture']
    assert_not_nil d['picture']
    assert_nil d['error']
  end

  test "should parse facebook page item 2" do
    m = create_media url: 'https://www.facebook.com/nostalgia.y/photos/pb.456182634511888.-2207520000.1484079948./928269767303170/?type=3&theater'
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal 'facebook', d['provider']
    assert_equal 'Nostalgia on Facebook', d['title']
    assert_match /مين قالك تسكن فى حاراتنا/, d['description']
    assert_not_nil d['published_at']
    assert_equal 'nostalgia.y', d['username']
    assert_equal 'Nostalgia', d['author_name']
    assert_equal 'http://facebook.com/456182634511888', d['author_url']
    assert_equal 'https://graph.facebook.com/456182634511888/picture', d['author_picture']
    assert_match /15181134_928269767303170_7195169848911975270/, d['picture']
    assert_nil d['error']
  end

  test "should set url with the permalink_url returned by facebook api" do
    m = create_media url: 'https://www.facebook.com/nostalgia.y/photos/a.508939832569501.1073741829.456182634511888/942167619246718/?type=3&theater'
    d = m.as_json
    assert_equal 'https://www.facebook.com/nostalgia.y/photos/a.508939832569501.1073741829.456182634511888/942167619246718/?type=3', m.url
  end

  test "should set url with the permalink_url returned by facebook api 2" do
    m = create_media url: 'https://www.facebook.com/nostalgia.y/posts/942167695913377'
    d = m.as_json
    assert_equal 'https://www.facebook.com/nostalgia.y/posts/942167695913377', m.url
  end

  test "should parse facebook url with colon mark" do
    m = create_media url: 'https://www.facebook.com/Classic.mou/posts/666508790193454:0'
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal 'facebook', d['provider']
    assert_equal '136985363145802_666508790193454', d['uuid']
    assert_equal 'Classic on Facebook', d['title']
    assert_match /إليزابيث تايلو/, d['description']
    assert_not_nil d['published_at']
    assert_equal 'Classic.mou', d['username']
    assert_equal 'Classic', d['author_name']
    assert_equal 'http://facebook.com/136985363145802', d['author_url']
    assert_equal 'https://graph.facebook.com/136985363145802/picture', d['author_picture']
    assert_match /16473884_666508790193454_8112186335057907723/, d['picture']
    assert_equal 'https://www.facebook.com/Classic.mou/photos/a.136991166478555.1073741828.136985363145802/666508790193454/?type=3', m.url
  end

  test "should parse pages when the scheme is missing on oembed url" do
    url = 'https://www.hongkongfp.com/2017/03/01/hearing-begins-in-govt-legal-challenge-against-4-rebel-hong-kong-lawmakers/'
    m = create_media url: url
    m.expects(:get_oembed_url).returns('//www.hongkongfp.com/wp-json/oembed/1.0/embed?url=https%3A%2F%2Fwww.hongkongfp.com%2F2017%2F03%2F01%2Fhearing-begins-in-govt-legal-challenge-against-4-rebel-hong-kong-lawmakers%2F')
    data = m.as_json
    assert_equal 'item', data['type']
    assert_equal 'page', data['provider']
    assert_match(/Hong Kong Free Press/, data['title'])
    assert_match(/Hong Kong/, data['description'])
    assert_not_nil data['published_at']
    assert_equal '@AFP', data['username']
    assert_equal 'https://twitter.com/AFP', data['author_url']
    assert_not_nil data['picture']
    assert_nil data['error']
  end

  test "should handle exception when raises some error when get oembed data" do
    url = 'https://www.hongkongfp.com/2017/03/01/hearing-begins-in-govt-legal-challenge-against-4-rebel-hong-kong-lawmakers/'
    m = create_media url: url
    m.expects(:get_oembed_url).raises(StandardError)
    data = m.as_json
    assert_equal 'item', data['type']
    assert_equal 'page', data['provider']
    assert_match(/Hong Kong Free Press/, data['title'])
    assert_match(/Hong Kong/, data['description'])
    assert_not_nil data['published_at']
    assert_equal '@AFP', data['username']
    assert_equal 'https://twitter.com/AFP', data['author_url']
    assert_not_nil data['picture']
    assert_match(/StandardError/, data['error']['message'])
  end

  test "should handle zlib error when opening a url" do
    m = create_media url: 'https://ca.yahoo.com'
    parsed_url = Media.parse_url( m.url)
    header_options = Media.send(:html_options, m.url)
    OpenURI.stubs(:open_uri).with(parsed_url, header_options).raises(Zlib::DataError)
    OpenURI.stubs(:open_uri).with(parsed_url, header_options.merge('Accept-Encoding' => 'identity'))
    m.send(:get_html, Media.send(:html_options, m.url))
    OpenURI.unstub(:open_uri)
  end

  test "should not notify Airbrake when it is a redirection from https to http" do
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)

    m = create_media url: 'https://www.scmp.com/news/china/diplomacy-defence/article/2110488/china-tries-build-bigger-bloc-stop-brics-crumbling'
    parsed_url = Media.parse_url(m.url)
    header_options = Media.send(:html_options, m.url)
    OpenURI.stubs(:open_uri).with(parsed_url, header_options).raises('redirection forbidden')
    Airbrake.configuration.stubs(:api_key).returns('token')

    m.send(:get_html, header_options)

    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_canonical_url)
    Media.any_instance.unstub(:try_https)
    OpenURI.unstub(:open_uri)
    Airbrake.configuration.unstub(:api_key)
  end

  test "should parse Facebook post from user profile and get username and name" do
    m = create_media url: 'https://www.facebook.com/nanabhay/posts/10156130657385246'
    data = m.as_json
    assert_equal 'Mohamed Nanabhay', data['author_name']
    assert_equal 'nanabhay', data['username']
  end

  test "should parse Facebook post from page and get username and name" do
    m = create_media url: 'https://www.facebook.com/ironmaiden/photos/a.406269382050.189128.172685102050/10154015223857051/?type=3&theater'
    data = m.as_json
    assert_equal 'Iron Maiden', data['author_name']
    assert_equal 'ironmaiden', data['username']
  end

  test "should parse Instagram post from page and get username and name" do
    m = create_media url: 'https://www.instagram.com/p/BJwkn34AqtN/'
    d = m.as_json
    assert_equal '@megadeth', d['username']
    assert_equal 'Megadeth', d['author_name']
  end

  test "should redirect to HTTPS if available and not already HTTPS" do
    m = create_media url: 'http://imotorhead.com'
    assert_equal 'https://imotorhead.com/', m.url
  end

  test "should not redirect to HTTPS if available and already HTTPS" do
    m = create_media url: 'https://imotorhead.com'
    assert_equal 'https://imotorhead.com/', m.url
  end

  test "should not redirect to HTTPS if not available" do
    m = create_media url: 'http://ca.ios.ba'
    assert_equal 'http://ca.ios.ba/', m.url
  end

  test "should parse dropbox video url" do
    m = create_media url: 'https://www.dropbox.com/s/2k0gocce8ry2xcx/videoplayback155.mp4?dl=0'
    d = m.as_json
    assert_equal 'https://www.dropbox.com/s/2k0gocce8ry2xcx/videoplayback155.mp4?dl=0', m.url
    assert_equal 'item', d['type']
    assert_equal 'dropbox', d['provider']
    assert_equal 'videoplayback155.mp4', d['title']
    assert_equal 'Shared with Dropbox', d['description']
    assert_not_nil d['published_at']
    assert_equal '', d['username']
    assert_equal '', d['author_url']
    assert_not_nil d['picture']
    assert_nil d['html']
    assert_nil d['error']
  end

  test "should parse dropbox image url" do
    m = create_media url: 'https://www.dropbox.com/s/up6n654gyysvk8v/b2604c14-8c7a-43e3-a286-dbb9e42bdf59.jpeg'
    d = m.as_json
    assert_equal 'https://www.dropbox.com/s/up6n654gyysvk8v/b2604c14-8c7a-43e3-a286-dbb9e42bdf59.jpeg',
    m.url
    assert_equal 'item', d['type']
    assert_equal 'dropbox', d['provider']
    assert_equal 'b2604c14-8c7a-43e3-a286-dbb9e42bdf59.jpeg', d['title']
    assert_equal 'Shared with Dropbox', d['description']
    assert_not_nil d['published_at']
    assert_equal '', d['username']
    assert_equal '', d['author_url']
    assert_not_nil d['picture']
    assert_nil d['html']
    assert_nil d['error']
  end

  test "should parse dropbox image url 2" do
    m = create_media url: 'https://dl.dropbox.com/s/up6n654gyysvk8v/b2604c14-8c7a-43e3-a286-dbb9e42bdf59.jpeg'
    d = m.as_json
    assert_equal 'https://dl.dropboxusercontent.com/s/up6n654gyysvk8v/b2604c14-8c7a-43e3-a286-dbb9e42bdf59.jpeg', m.url
    assert_equal 'item', d['type']
    assert_equal 'dropbox', d['provider']
    assert_equal 'b2604c14-8c7a-43e3-a286-dbb9e42bdf59.jpeg', d['title']
    assert_equal 'Shared with Dropbox', d['description']
    assert_not_nil d['published_at']
    assert_equal '', d['username']
    assert_equal '', d['author_url']
    assert_not_nil d['picture']
    assert_nil d['html']
    assert_nil d['error']
  end

  test "should parse dropbox url with sh" do
    m = create_media url: 'https://www.dropbox.com/sh/748f94925f0gesq/AAAMSoRJyhJFfkupnAU0wXuva?dl=0'
    d = m.as_json
    assert_equal 'https://www.dropbox.com/sh/748f94925f0gesq/AAAMSoRJyhJFfkupnAU0wXuva?dl=0', m.url
    assert_equal 'item', d['type']
    assert_equal 'dropbox', d['provider']
    assert !d['title'].blank?
    assert_equal 'Shared with Dropbox', d['description']
    assert_not_nil d['published_at']
    assert_equal '', d['username']
    assert_equal '', d['author_url']
    assert_not_nil d['picture']
    assert_nil d['html']
    assert_nil d['error']
  end

  test "should return empty html on oembed when frame is not allowed" do
    m = create_media url: 'https://martinoei.com/article/13371/%e9%81%b8%e6%b0%91%e7%99%bb%e8%a8%98-%e5%a4%b1%e7%ab%8a%e4%ba%8b%e4%bb%b6%e8%b6%8a%e8%a7%a3%e8%b6%8a%e4%bc%bcx%e6%aa%94%e6%a1%88'
    data = m.as_json
    assert_equal '', data['html']
  end

  test "should parse Facebook post from media set" do
    m = create_media url: 'https://www.facebook.com/media/set/?set=a.10154534110871407.1073742048.54212446406&type=3'
    d = m.as_json
    assert_equal '54212446406_10154534110871407', d['uuid']
    assert_match(/En el Museo Serralves de Oporto/, d['text'])
    assert_equal '54212446406', d['user_uuid']
    assert_equal 'Mariano Rajoy Brey', d['author_name']
    assert d['media_count'] > 20
    assert_equal '10154534110871407', d['object_id']
    assert_equal 'https://www.facebook.com/media/set/?set=a.10154534110871407.1073742048.54212446406&type=3', m.url
  end

  test "should get all information of a truncated tweet" do
    m = create_media url: 'https://twitter.com/bradymakesstuff/status/844240817334247425'
    d = m.as_json
    assert_equal 'Anti immigrant graffiti in a portajon on a residential construction site in Mtn Brook, AL. Job has about 50% Latino workers. https://t.co/bS5vI4Jq7I', d['description']
    assert_not_nil d['raw']['api']['entities']['media'][0]['media_url_https']
  end

  test "should support facebook pattern with pg" do
    m = create_media url: 'https://www.facebook.com/pg/Mariano-Rajoy-Brey-54212446406/photos/?tab=album&album_id=10154534110871407'
    d = m.as_json
    assert_equal '54212446406_10154534110871407', d['uuid']
    assert_match(/Presidente del Partido Popular/, d['text'])
    assert_equal '54212446406', d['user_uuid']
    assert_equal 'Mariano Rajoy Brey', d['author_name']
    assert_equal '10154534110871407', d['object_id']
    assert_equal 'https://www.facebook.com/Mariano-Rajoy-Brey-54212446406/photos', m.url
  end

  test "should support facebook pattern with album" do
    m = create_media url: 'https://www.facebook.com/album.php?fbid=10154534110871407&id=54212446406&aid=1073742048'
    d = m.as_json
    assert_equal '54212446406_10154534110871407', d['uuid']
    assert_match(/En el Museo Serralves de Oporto/, d['text'])
    assert_equal '54212446406', d['user_uuid']
    assert_equal 'Mariano Rajoy Brey', d['author_name']
    assert d['media_count'] > 20
    assert_equal '10154534110871407', d['object_id']
    assert_equal 'https://www.facebook.com/media/set/?set=a.10154534110871407.1073742048.54212446406&type=3', m.url
  end

  test "should get facebook data from original_url when url fails" do
    Media.any_instance.stubs(:url).returns('https://www.facebook.com/Mariano-Rajoy-Brey-54212446406/photos')
    Media.any_instance.stubs(:original_url).returns('https://www.facebook.com/pg/Mariano-Rajoy-Brey-54212446406/photos/?tab=album&album_id=10154534110871407')
    m = create_media url: 'https://www.facebook.com/pg/Mariano-Rajoy-Brey-54212446406/photos'
    d = m.as_json
    assert_equal '54212446406_10154534110871407', d['uuid']
    assert_match(/Presidente del Partido Popular/, d['text'])
    assert_equal '54212446406', d['user_uuid']
    assert_equal 'Mariano Rajoy Brey', d['author_name']
    assert_equal '10154534110871407', d['object_id']
    Media.any_instance.unstub(:url)
    Media.any_instance.unstub(:original_url)
  end

  test "should parse as html when API token is expired and notify Airbrake" do
    fb_token = CONFIG['facebook_auth_token']
    Airbrake.configuration.stubs(:api_key).returns('token')
    Airbrake.stubs(:notify).once
    CONFIG['facebook_auth_token'] = 'EAACMBapoawsBAP8ugWtoTpZBpI68HdM68qgVdLNc8R0F8HMBvTU1mOcZA4R91BsHZAZAvSfTktgBrdjqhYJq2Qet2RMsNZAu12J14NqsP1oyIt74vXlFOBkR7IyjRLLVDysoUploWZC1N76FMPf5Dzvz9Sl0EymSkZD'
    m = create_media url: 'https://www.facebook.com/nostalgia.y/photos/a.508939832569501.1073741829.456182634511888/942167619246718/?type=3&theater'
    data = m.as_json
    assert_equal 'Nostalgia on Facebook', data['title']
    CONFIG['facebook_auth_token'] = fb_token
    data = m.as_json(force: 1)
    assert_equal 'Nostalgia on Facebook', data['title']
    Airbrake.configuration.unstub(:api_key)
    Airbrake.unstub(:notify)
  end

  test "should keep port when building author_url if port is not 443 or 80" do
    Media.any_instance.stubs(:archive_to_screenshot).returns('')
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:data_from_page_item)

    url = 'https://mediatheque.karimratib.me:5001/as/sharing/uhfxuitn'
    m = create_media url: url
    assert_equal 'https://mediatheque.karimratib.me:5001', m.send(:top_url, m.url)

    url = 'http://ca.ios.ba/slack'
    m = create_media url: url
    assert_equal 'http://ca.ios.ba', m.send(:top_url, m.url)

    url = 'https://meedan.com/en/check'
    m = create_media url: url
    assert_equal 'https://meedan.com', m.send(:top_url, m.url)

    Media.any_instance.unstub(:archive_to_screenshot)
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_canonical_url)
    Media.any_instance.unstub(:try_https)
    Media.any_instance.unstub(:data_from_page_item)
  end

  test "should store metatags in an Array" do
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    m = create_media url: 'https://www.nytimes.com/2017/06/14/us/politics/mueller-trump-special-counsel-investigation.html', request: request
    data = m.as_json
    assert data['raw']['metatags'].is_a? Array
    assert !data['raw']['metatags'].empty?
  end

  test "should store data of a profile returned by facebook API" do
    m = create_media url: 'https://www.facebook.com/profile.php?id=100008161175765&fref=ts'
    data = m.as_json

    assert_equal 'Tico-Santa-Cruz', data[:username]
    assert_equal 'Tico Santa Cruz', data[:title]
    assert !data[:picture].blank?
  end

  test "should store data of post returned by instagram api and graphql" do
    m = create_media url: 'https://www.instagram.com/p/BJwkn34AqtN/'
    data = m.as_json
    assert data['raw']['api'].is_a? Hash
    assert !data['raw']['api'].empty?

    assert data['raw']['graphql'].is_a? Hash
    assert !data['raw']['graphql'].empty?

    assert_equal '@megadeth', data[:username]
    assert_match /Peace Sells/, data[:description]
    assert_match /Peace Sells/, data[:title]
    assert !data[:picture].blank?
    assert_equal "https://www.instagram.com/megadeth", data[:author_url]
    assert !data[:html].blank?
    assert !data[:author_picture].blank?
    assert_equal 'Megadeth', data[:author_name]
    assert !data[:published_at].blank?
  end

  test "should store data of post returned by oembed" do
    m = create_media url: 'https://www.facebook.com/teste637621352/posts/1028416870556238'
    oembed = m.as_json['raw']['oembed']
    assert oembed.is_a? Hash
    assert !oembed.empty?

    assert_nil oembed['title']
    assert_equal 'Teste', oembed['author_name']
    assert_equal 'https://www.facebook.com/teste637621352/', oembed['author_url']
    assert_equal 'Facebook', oembed['provider_name']
    assert_equal 'https://www.facebook.com', oembed['provider_url']
    assert_equal 552, oembed['width']
    assert oembed['height'].nil?
  end

  test "should store data of post returned by twitter API" do
    m = create_media url: 'https://twitter.com/caiosba/status/742779467521773568'
    data = m.as_json
    assert data['raw']['api'].is_a? Hash
    assert !data['raw']['api'].empty?

    assert_equal 'I\'ll be talking in @rubyconfbr this year! More details soon...', data['title']
  end

  test "should store data of profile returned by twitter API" do
    m = create_media url: 'https://twitter.com/caiosba'
    data = m.as_json
    assert data['raw']['api'].is_a? Hash
    assert !data['raw']['api'].empty?
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

  test "should store oembed data of a facebook post" do
    m = create_media url: 'https://www.facebook.com/nostalgia.y/photos/a.508939832569501.1073741829.456182634511888/942167619246718/?type=3&theater'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal "https://www.facebook.com", data['raw']['oembed']['provider_url']
    assert_equal "Facebook", data['raw']['oembed']['provider_name']
  end

  test "should store oembed data of a facebook profile" do
    m = create_media url: 'https://www.facebook.com/profile.php?id=100008161175765&fref=ts'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal 'Tico-Santa-Cruz', data['raw']['oembed']['author_name']
    assert_equal 'Tico Santa Cruz', data['raw']['oembed']['title']
  end

  test "should store oembed data of a facebook page" do
    m = create_media url: 'https://www.facebook.com/pages/Meedan/105510962816034?fref=ts'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal 'Meedan', data['raw']['oembed']['author_name']
    assert_equal 'Meedan', data['raw']['oembed']['title']
  end

  test "should store oembed data of a instagram post" do
    m = create_media url: 'https://www.instagram.com/p/BJwkn34AqtN/'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal 'megadeth', data['raw']['oembed']['author_name']
    assert_match /Peace Sells/, data['raw']['oembed']['title']
  end

  test "should store oembed data of a twitter post" do
    m = create_media url: 'https://twitter.com/caiosba/status/742779467521773568'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal "https:\/\/twitter.com", data['raw']['oembed']['provider_url']
    assert_equal "Twitter", data['raw']['oembed']['provider_name']
  end

  test "should store oembed data of a twitter profile" do
    m = create_media url: 'https://twitter.com/caiosba'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal "https:\/\/twitter.com", data['raw']['oembed']['provider_url']
    assert_equal "Twitter", data['raw']['oembed']['provider_name']
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

  test "should not return empty values on metadata keys due to bad html" do
    m = create_media url: 'http://www.politifact.com/truth-o-meter/article/2017/may/09/year-fact-checking-about-james-comey-clinton-email/'
    tag_description = m.as_json['raw']['metatags'].find { |tag| tag['property'] == 'og:description'}
    assert_equal ['property', 'content'], tag_description.keys
    assert_match /\AJames Comey is out as FBI director.*last July.\z/, tag_description['content']
  end

  test "should use username as author_name on Instagram profile when a full name is not available" do
    m = create_media url: 'https://www.instagram.com/emeliiejanssonn/'
    data = m.as_json
    assert_equal 'emeliiejanssonn', data['author_name']
  end

  test "should create Facebook post from page post URL without login" do
    m = create_media url: 'https://www.facebook.com/photo.php?fbid=10156907731480246&set=pb.735450245.-2207520000.1502314039.&type=3&theater'
    d = m.as_json
    assert_equal 'Mohamed Nanabhay on Facebook', d['title']
    assert_equal 'Somewhere off the Aegean Coast....', d['description']
    assert_equal 'Mohamed Nanabhay', d['author_name']
    assert_equal 'nanabhay', d['username']
    assert_equal 'https://graph.facebook.com/735450245/picture', d['author_picture']
    assert_equal 0, d['media_count']
    assert_not_nil d['picture']
  end

  test "should parse url with redirection https -> http" do
    m = create_media url: 'https://noticias.uol.com.br/cotidiano/ultimas-noticias/2017/07/18/nove-anos-apos-ser-condenado-por-moro-beira-mar-repete-trafico-em-presidio-federal.htm'
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal 'page', d['provider']
    assert_match /Nove anos após ser condenado/, d['title']
    assert_not_nil d['description']
    assert_not_nil d['published_at']
    assert_equal '', d['username']
    assert_equal 'https://noticias.uol.com.br', d['author_url']
    assert_equal '@UOL', d['author_name']
    assert_not_nil d['picture']
    assert_nil d['error']
  end

  test "should get author_name from site" do
    m = create_media url: 'https://noticias.uol.com.br/'
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal 'page', d['provider']
    assert_match /Acompanhe as últimas notícias do Brasil e do mundo/, d['title']
    assert_not_nil d['description']
    assert_not_nil d['published_at']
    assert_equal '', d['username']
    assert_equal 'https://noticias.uol.com.br', d['author_url']
    assert_equal '@UOL', d['author_name']
    assert_not_nil d['picture']
    assert_nil d['error']
  end

  test "should check if article:author is a url and add it to author_url" do
    m = create_media url: 'https://www.nytimes.com/2017/06/14/us/politics/mueller-trump-special-counsel-investigation.html'
    tag = [{property: 'article:author', content: 'https://www.nytimes.com/by/michael-s-schmidt'}]
    m.data[:raw] = { metatags: tag }
    data = m.get_opengraph_metadata
    assert_nil data['username']
    assert_equal 'https://www.nytimes.com/by/michael-s-schmidt', data['author_url']
  end

  test "should return blank on post_process_oembed for unexistent keys on oembed" do
    m = create_media url: 'https://www.nytimes.com/2017/06/14/us/politics/mueller-trump-special-counsel-investigation.html'
    m.data[:raw] = {}
    fields = %w(username description title picture html author_url)
    fields.each { |f| m.data[f] = f }
    response = 'mock';response.expects(:code).returns('200');response.expects(:body).returns('{"type":"rich"}').twice;response.expects(:header).returns({})
    m.stubs(:oembed_get_data_from_url).returns(response)

    oembed_data = m.data_from_oembed_item
    m.post_process_oembed_data
    fields.each do |f|
      assert_equal f, m.data[f]
    end
    m.unstub(:oembed_get_data_from_url)
  end

  test "should store json+ld data as a json string" do
    m = create_media url: 'http://www.example.com'
    doc = ''
    open('test/data/page-with-json-ld.html') { |f| doc = f.read }
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML(doc))
    m.data = Media.minimal_data(m)
    m.get_jsonld_data(m)

    assert !m.data['raw']['json+ld'].empty?
    assert m.data['raw']['json+ld'].is_a? Hash
    Media.any_instance.unstub(:doc)
  end

  test "should not have the subkey json+ld if the tag is not present on page" do
    m = create_media url: 'https://www.instagram.com/emeliiejanssonn/'
    data = m.as_json

    assert data['raw']['json+ld'].nil?
  end

  test "should return empty html on oembed when script has http src" do
    m = create_media url: 'https://politi.co/2j7qyT0'
    oembed = '{"version":"1.0","type":"rich","html":"<script type=\"text/javascript\" src=\"http://www.politico.com/story/2017/09/07/facebook-fake-news-social-media-242407?_embed=true&amp;_format=js\"></script>"}'
    response = 'mock';response.expects(:code).returns('200');response.stubs(:body).returns(oembed)
    Media.any_instance.stubs(:oembed_get_data_from_url).with(m.get_oembed_url).returns(response);response.expects(:header).returns({})
    data = m.as_json
    response = m.oembed_get_data_from_url(m.get_oembed_url)
    assert_match /script.*src="http:\/\//, JSON.parse(response.body)['html']
    assert_equal '', data['html']
    Media.any_instance.unstub(:oembed_get_data_from_url)
  end

  test "should decode html entities" do
    m = create_media url: 'https://twitter.com/cal_fire/status/919029734847025152'
    data = m.as_json
    assert_no_match /&amp;/, data['title']
  end

  test "should take full screenshot, update cache and call webhook" do
    Media.any_instance.unstub(:archive_to_screenshot)
    a = create_api_key application_settings: { 'webhook_url': 'https://webhook.site/19cfeb40-3d06-41b8-8378-152fe12e29a8', 'webhook_token': 'test' }
    url = 'https://twitter.com/marcouza'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    data = m.as_json
    filename = Digest::MD5.hexdigest(m.url.parameterize) + '.png'
    path = File.join(Rails.root, 'public', 'screenshots', filename)
    assert File.exists?(path)
    assert_equal 0, Rails.cache.read(id)['screenshot_taken']
    assert_nil Rails.cache.read(id)['webhook_called']
    sleep 70 # Wait enough for the scheduler
    dimensions = IO.read(path)[0x10..0x18].unpack('NN')
    assert dimensions[1] > 2000
    assert_equal 1, Rails.cache.read(id)['screenshot_taken']
    assert_equal 1, Rails.cache.read(id)['webhook_called']
  end

  test "should skip screenshots" do
    config = CONFIG['archiver_skip_hosts']

    CONFIG['archiver_skip_hosts'] = ''

    Media.any_instance.unstub(:archive_to_screenshot)
    a = create_api_key application_settings: { 'webhook_url': 'https://webhook.site/19cfeb40-3d06-41b8-8378-152fe12e29a8', 'webhook_token': 'test' }
    url = 'https://checkmedia.org/caio-screenshots/project/1121/media/8390'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    data = m.as_json
    filename = Digest::MD5.hexdigest(url.parameterize) + '.png'
    path = File.join(Rails.root, 'public', 'screenshots', filename)
    assert File.exists?(path)

    CONFIG['archiver_skip_hosts'] = 'checkmedia.org'

    url = 'https://checkmedia.org/caio-screenshots/project/1121/media/8390?hide_tasks=1'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    data = m.as_json
    filename = url.parameterize + '.png'
    path = File.join(Rails.root, 'public', 'screenshots', filename)
    assert !File.exists?(path)

    CONFIG['archiver_skip_hosts'] = config
  end

  test "should archive to Video Vault" do
    config = CONFIG['video_vault_token']
    CONFIG['video_vault_token'] = '123456'

    Media.any_instance.unstub(:archive_to_video_vault)
    a = create_api_key application_settings: { 'webhook_url': 'https://webhook.site/19cfeb40-3d06-41b8-8378-152fe12e29a8', 'webhook_token': 'test' }
    url = 'https://twitter.com/marcouza/status/875424957613920256'
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'www.bravenewtech.org' }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, 'https://www.bravenewtech.org/api/').to_return(body: { status: 203, package: '123456' }.to_json)
    WebMock.stub_request(:any, 'https://www.bravenewtech.org/api/status.php').to_return(body: { location: 'http://videovault/123456' }.to_json)

    assert_nothing_raised do
      m = create_media url: url, key: a
      data = m.as_json
    end

    CONFIG['video_vault_token'] = config
    WebMock.disable!
  end

  test "should archive to Archive.is" do
    Media.any_instance.unstub(:archive_to_archive_is)
    a = create_api_key application_settings: { 'webhook_url': 'https://webhook.site/19cfeb40-3d06-41b8-8378-152fe12e29a8', 'webhook_token': 'test' }
    urls = ['https://twitter.com/marcouza/status/875424957613920256', 'https://twitter.com/marcouza/status/863907872421412864', 'https://twitter.com/marcouza/status/863876311428861952']
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'archive.is' }
    WebMock.disable_net_connect!(allow: allowed_sites)

    assert_nothing_raised do
      WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { refresh: '1' })
      m = create_media url: urls[0], key: a
      data = m.as_json

      WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { location: 'http://archive.is/test' })
      m = create_media url: urls[1], key: a
      data = m.as_json
    end

    assert_raises RuntimeError do
      WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '')
      m = create_media url: urls[2], key: a
      data = m.as_json
    end

    WebMock.disable!
  end

  test "should store ClaimReview schema" do
    url = 'http://www.politifact.com/truth-o-meter/statements/2017/aug/17/donald-trump/donald-trump-retells-pants-fire-claim-about-gen-pe'
    m = create_media url: url
    data = m.as_json
    claim_review = data['schema']['ClaimReview'].first
    assert_equal 'ClaimReview', claim_review['@type']
    assert_equal 'http://schema.org', claim_review['@context']
    assert_equal ['@context', '@type', 'author', 'claimReviewed', 'datePublished', 'itemReviewed', 'reviewRating', 'url'], claim_review.keys.sort
  end

  test "should return nil on schema key if not found on page" do
    url = 'http://ca.ios.ba/'
    m = create_media url: url
    data = m.as_json
    assert data['schema'].nil?
  end

  test "should store all schemas as array" do
    url = 'https://g1.globo.com/sp/sao-paulo/noticia/pf-indicia-haddad-por-caixa-2-em-campanha-para-a-prefeitura-de-sp.ghtml'
    m = create_media url: url
    data = m.as_json
    assert_equal ["NewsArticle", "VideoObject", "WebPage"], data['schema'].keys.sort
    assert data['schema']['NewsArticle'].is_a? Array
    assert data['schema']['VideoObject'].is_a? Array
  end

  test "should store ClaimReview schema after preprocess" do
    url = 'http://www.politifact.com/global-news/statements/2017/feb/17/bob-corker/are-27-million-people-trapped-modern-slavery'
    m = create_media url: url
    data = m.as_json
    assert data['error'].nil?
    assert_equal 'ClaimReview', data['schema']['ClaimReview'].first['@type']
    assert_equal ['@context', '@type', 'author', 'claimReviewed', 'datePublished', 'itemReviewed', 'reviewRating', 'url'], data['schema']['ClaimReview'].first.keys.sort
  end

  test "should archive to Archive.org" do
    Media.any_instance.unstub(:archive_to_archive_org)
    a = create_api_key application_settings: { 'webhook_url': 'https://webhook.site/19cfeb40-3d06-41b8-8378-152fe12e29a8', 'webhook_token': 'test' }
    urls = ['https://twitter.com/marcouza/status/875424957613920256', 'https://twitter.com/marcouza/status/863907872421412864']
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'web.archive.org' }
    WebMock.disable_net_connect!(allow: allowed_sites)

    assert_nothing_raised do
      WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: {})
      m = create_media url: urls[0], key: a
      data = m.as_json

      WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/web/123456/test' })
      m = create_media url: urls[1], key: a
      data = m.as_json
    end

    WebMock.disable!
  end

  test "should archive Arabics url to Archive.org" do
    Media.any_instance.unstub(:archive_to_archive_org)
    a = create_api_key application_settings: { 'webhook_url': 'https://webhook.site/19cfeb40-3d06-41b8-8378-152fe12e29a8', 'webhook_token': 'test' }
    urls = ['https://www.madamasr.com/ar/2018/03/13/feature/%D8%B3%D9%8A%D8%A7%D8%B3%D8%A9/%D9%82%D8%B1%D8%A7%D8%A1%D8%A9-%D9%81%D9%8A-%D8%AC%D8%B1%D8%A7%D8%A6%D9%85-%D8%A7%D9%84%D9%85%D8%B9%D9%84%D9%88%D9%85%D8%A7%D8%AA-%D8%AA%D9%82%D9%86%D9%8A%D9%86-%D9%84%D9%84%D8%AD%D8%AC', 'http://www.yallakora.com/ar/news/342470/%D8%A7%D8%AA%D8%AD%D8%A7%D8%AF-%D8%A7%D9%84%D9%83%D8%B1%D8%A9-%D8%B9%D9%86-%D8%A3%D8%B2%D9%85%D8%A9-%D8%A7%D9%84%D8%B3%D8%B9%D9%8A%D8%AF-%D9%84%D8%A7%D8%A8%D8%AF-%D9%85%D9%86-%D8%AD%D9%84-%D9%85%D8%B9-%D8%A7%D9%84%D8%B2%D9%85%D8%A7%D9%84%D9%83/2504']
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'web.archive.org' }
    WebMock.disable_net_connect!(allow: allowed_sites)

    assert_nothing_raised do
      WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: {})
      m = create_media url: urls[0], key: a
      data = m.as_json

      WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/web/123456/test' })
      m = create_media url: urls[1], key: a
      data = m.as_json
    end

    WebMock.disable!
  end

  test "should validate author_url when taken from twitter metatags" do
    url = 'http://lnphil.blogspot.com.br/2018/01/villar-at-duterte-nagsanib-pwersa-para.html'
    m = create_media url: url
    data = m.as_json
    assert_equal m.send(:top_url, m.url), data['author_url']
    assert_equal '', data['username']
  end

  test "should use md5 hash on screenshot filename" do
    Media.any_instance.unstub(:archive_to_screenshot)
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    url = 'https://www.madamasr.com/ar/2018/03/13/feature/%D8%B3%D9%8A%D8%A7%D8%B3%D8%A9/%D9%82%D8%B1%D8%A7%D8%A1%D8%A9-%D9%81%D9%8A-%D8%AC%D8%B1%D8%A7%D8%A6%D9%85-%D8%A7%D9%84%D9%85%D8%B9%D9%84%D9%88%D9%85%D8%A7%D8%AA-%D8%AA%D9%82%D9%86%D9%8A%D9%86-%D9%84%D9%84%D8%AD%D8%AC'
    m = create_media url: url, request: request
    data = m.as_json
    filename = Digest::MD5.hexdigest(url.parameterize) + '.png'
    path = File.join(Rails.root, 'public', 'screenshots', filename)
    assert File.exists?(path)
    assert_match /\/screenshots\/#{filename}$/, data['screenshot']
    assert data['error'].nil?
  end

  test "should handle error when cannot get twitter url" do
    Media.any_instance.unstub(:archive_to_screenshot)
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    Media.any_instance.stubs(:twitter_client).raises(Twitter::Error::Forbidden)
    url = 'http://www.yallakora.com/ar/news/342470/%D8%A7%D8%AA%D8%AD%D8%A7%D8%AF-%D8%A7%D9%84%D9%83%D8%B1%D8%A9-%D8%B9%D9%86-%D8%A3%D8%B2%D9%85%D8%A9-%D8%A7%D9%84%D8%B3%D8%B9%D9%8A%D8%AF-%D9%84%D8%A7%D8%A8%D8%AF-%D9%85%D9%86-%D8%AD%D9%84-%D9%85%D8%B9-%D8%A7%D9%84%D8%B2%D9%85%D8%A7%D9%84%D9%83/2504'
    m = create_media url: url, request: request
    data = m.as_json
    assert data['error'].nil?
    Media.any_instance.unstub(:twitter_client)
  end

  test "should handle errors when call parse" do
    Media.any_instance.unstub(:archive_to_screenshot)
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    url = 'http://example.com'
    m = create_media url: url, request: request
    %w(oembed_item instagram_profile instagram_item page_item dropbox_item bridge_item facebook_item).each do |parser|
      Media.any_instance.stubs("data_from_#{parser}").raises(StandardError)
      data = m.as_json
      assert_equal "StandardError: StandardError", data['error']['message']
      Media.any_instance.unstub("data_from_#{parser}")
    end
  end

  test "should parse website" do
    url = 'http://www.acdc.com'
    m = create_media url: url
    data = m.as_json
    assert_equal 'Homepage', data['title']
  end

  test "should have a transitive relation between normalized URLs" do
    url = 'https://www.facebook.com/quoted.pictures/photos/a.128828073875334.28784.128791873878954/1096134023811396/?type=3&theater'
    m = create_media url: url
    data = m.as_json
    url = 'https://www.facebook.com/quoted.pictures/photos/a.128828073875334.28784.128791873878954/1096134023811396/?type=3'
    assert_equal url, data['url']

    m = create_media url: url
    data = m.as_json
    assert_equal url, data['url']
  end

  test "should parse medium posts" do
    url = 'https://medium.com/darius-foroux/how-to-retain-more-from-the-books-you-read-in-5-simple-steps-700d90653a41'
    m = create_media url: url
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal 'page', d['provider']
    assert_equal 'How To Retain More From The Books You Read In 5 Simple Steps', d['title']
    assert_equal 'Don’t read more. Read smarter.', d['description']
    assert_equal '@DariusForoux', d['username']
    assert_equal 'https://twitter.com/DariusForoux', d['author_url']
    assert_not_nil d['picture']
    assert_nil d['error']
  end

  test "should parse globalvoices url" do
    url = 'https://globalvoices.org/2018/05/01/kidnapping-and-murders-as-ecuador-and-colombias-border-crisis-heightens'
    m = Media.new url: url
    d = m.as_json
    assert_equal 'Kidnapping and murders as Ecuador and Colombia’s border crisis heightens · Global Voices', d['title']
    assert_equal 'Reaching a peace agreement that puts an end to one of the oldest conflicts in the hemisphere is complicated by the murder of three members of the newspaper El Comercio.', d['description']
    assert_equal '@sobretematicas', d['username']
    assert_equal 'https://es.globalvoices.org/wp-content/uploads/2018/04/NosFaltan3-641x450.jpg', d['picture']
    assert_equal 'https://twitter.com/sobretematicas', d['author_url']
    assert_equal 'https://es.globalvoices.org/wp-content/uploads/2018/04/NosFaltan3-641x450.jpg', d['author_picture']
    assert_equal '@globalvoices', d['author_name']
    assert_not_nil d['published_at']
  end

  test "should parse twitter profile urls with mobile pattern" do
    expected = 'https://twitter.com/meedan'
    variations = %w(
      0.twitter.com/meedan
      m.twitter.com/meedan
      mobile.twitter.com/meedan
    )
    variations.each do |url|
      m = Media.new(url: url)
      data = m.as_json
      assert_equal expected, m.url
      assert_equal 'twitter', data['provider']
      assert_equal 'profile', data['type']
      assert_equal 'meedan', data['title']
      assert_equal '@meedan', data['username']
      assert_equal 'meedan', data['author_name']
      assert_not_nil data['description']
      assert_not_nil data['picture']
      assert_not_nil data['published_at']
      assert_nil data['error']
    end
  end

  test "should parse tweet urls with mobile pattern" do
    expected = 'https://twitter.com/meedan/status/998945357001314304'
    variations = %w(
      0.twitter.com/meedan/status/998945357001314304
      m.twitter.com/meedan/status/998945357001314304
      mobile.twitter.com/meedan/status/998945357001314304
    )
    variations.each do |url|
      m = Media.new(url: url)
      data = m.as_json
      assert_equal expected, m.url
      assert_equal 'twitter', data['provider']
      assert_equal 'item', data['type']
      assert_match /A guide to anti-misinformation/, data['title']
      assert_equal '@meedan', data['username']
      assert_equal 'meedan', data['author_name']
      assert_not_nil data['description']
      assert_not_nil data['published_at']
      assert_nil data['error']
    end
  end

  test "should parse posts from twitter subdomains as page" do
    variations = %w(
      https://blog.twitter.com
      https://blog.twitter.com/official/en_us/topics/events/2018/Embrace-Ramadan-with-various-Twitter-only-activations.html
      https://business.twitter.com
      https://business.twitter.com/en/blog/4-tips-Tweeting-live-events.html
    )
    variations.each do |url|
      m = Media.new(url: url)
      data = m.as_json
      assert_equal 'page', data['provider']
    end
  end

end
