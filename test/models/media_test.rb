require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

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
    assert_equal 'user', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse YouTube channel" do
    m = create_media url: 'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ'
    data = m.as_json
    assert_equal 'Iron Maiden', data['title']
    assert_equal 'ironmaiden', data['username']
    assert_equal 'user', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
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
    data = m.as_json
    assert_equal 'Caio Almeida', data['title']
    assert_equal 'caiosba', data['username']
    assert_equal 'twitter', data['provider']
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
    data = m.as_oembed("http://pender.org/medias.html?url=#{url}", 300, 150)
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

  test "should parse Checkdesk report" do
    m = create_media url: 'https://meedan.checkdesk.org/node/2161'
    data = m.as_json
    assert_equal 'Twitter / History In Pictures: Little Girl &amp; Ba...', data['title']
    assert_equal 'Tom', data['username']
    assert_equal 'oembed', data['provider']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse Facebook with numeric id" do
    m = create_media url: 'http://facebook.com/513415662050479'
    data = m.as_json
    assert_equal 'https://www.facebook.com/NautilusMag', data['url']
    assert_equal 'Nautilus Magazine', data['title']
  end

  test "should parse YouTube user with slash" do
    m = create_media url: 'https://www.youtube.com/user/portadosfundos/'
    data = m.as_json
    assert_equal 'Porta dos Fundos', data['title']
    assert_equal 'portadosfundos', data['username']
    assert_equal 'user', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse YouTube channel with slash" do
    m = create_media url: 'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ/'
    data = m.as_json
    assert_equal 'Iron Maiden', data['title']
    assert_equal 'ironmaiden', data['username']
    assert_equal 'user', data['subtype']
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

    media = Media.new(url: 'http://ca.ios.ba/a%c2/%7Euser?a=b')
    assert_equal 'http://ca.ios.ba/a%C2/~user?a=b', media.url
  end

  test "should not normalize URL" do
    urls = %w(
      http://meedan.com/en/
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
    assert_equal 'caiosba', data['username']
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
      assert_match /http:\/\/www.almasryalyoum.com\/editor\/details\/968/, data['url']
    end
  end

  test "should parse HTTP-authed URL" do
    m = create_media url: 'http://qa.checkdesk.org/en/source/2777'
    data = m.as_json
    assert_equal 'Western Sahara AF', data['title']
  end

  test "should parse Facebook user profile using user token" do
    m = create_media url: 'https://facebook.com/1061897617191825'
    data = m.as_json
    assert_equal 'Caio Sacramento', data['title']
    assert_equal 'caiosba', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'user', data['subtype']
    assert_equal 'https://www.facebook.com/caiosba', data['url']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse numeric Facebook profile" do
    m = create_media url: 'https://facebook.com/100013581666047'
    data = m.as_json
    assert_equal 'José Silva', data['title']
  end

  # http://errbit.test.meedan.net/apps/576218088583c6f1ea000231/problems/57a1bf968583c6f1ea000c01
  # https://mantis.meedan.com/view.php?id=4913
  test "should parse numeric Facebook profile 2" do
    m = create_media url: 'https://facebook.com/10153811412781094'
    data = m.as_json
    assert_equal 'Noha Nazieh Daoud', data['title']
  end

  test "should parse tweet" do
    m = create_media url: 'https://twitter.com/caiosba/status/742779467521773568'
    data = m.as_json
    assert_equal 'I\'ll be talking in @rubyconfbr this year! More details soon...', data['title']
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
    assert_equal 'Teste', d['user_name']
    assert_equal 0, d['media_count']
    assert_equal '1028416870556238', d['object_id']
    assert_equal '18/11/2015', Time.parse(d['published']).strftime("%d/%m/%Y")
  end

  test "should create Facebook post from page photo URL" do
    m = create_media url: 'https://www.facebook.com/teste637621352/photos/a.754851877912740.1073741826.749262715138323/896869113711015/?type=3'
    d = m.as_json
    assert_equal '749262715138323_896869113711015', d['uuid']
    assert_equal 'This post should be fetched.', d['text']
    assert_equal '749262715138323', d['user_uuid']
    assert_equal 'Teste', d['user_name']
    assert_equal 1, d['media_count']
    assert_equal '896869113711015', d['object_id']
    assert_equal '09/03/2015', Time.parse(d['published']).strftime("%d/%m/%Y")
  end

  test "should create Facebook post from page photo URL 2" do
    m = create_media url: 'https://www.facebook.com/photo.php?fbid=1028424567222135&set=a.1028424563888802.1073741827.749262715138323&type=3'
    d = m.as_json
    assert_equal '749262715138323_1028424567222135', d['uuid']
    assert_equal 'Teste updated their profile picture.', d['text']
    assert_equal '749262715138323', d['user_uuid']
    assert_equal 'Teste', d['user_name']
    assert_equal 1, d['media_count']
    assert_equal '1028424567222135', d['object_id']
    assert_equal '18/11/2015', Time.parse(d['published']).strftime("%d/%m/%Y")
  end

  test "should create Facebook post from page photos URL" do
    m = create_media url: 'https://www.facebook.com/teste637621352/posts/1028795030518422'
    d = m.as_json
    assert_equal '749262715138323_1028795030518422', d['uuid']
    assert_equal 'This is just a test with many photos.', d['text']
    assert_equal '749262715138323', d['user_uuid']
    assert_equal 'Teste', d['user_name']
    assert_equal 2, d['media_count']
    assert_equal '1028795030518422', d['object_id']
    assert_equal '18/11/2015', Time.parse(d['published']).strftime("%d/%m/%Y")
  end

  test "should create Facebook post from user photos URL" do
    m = create_media url: 'https://www.facebook.com/nanabhay/posts/10156130657385246?pnref=story'
    d = m.as_json
    assert_equal '735450245_10156130657385246', d['uuid']
    assert_equal 'Such a great evening with friends last night. Sultan Sooud Al-Qassemi has an amazing collecting of modern Arab art. It was a visual tour of the history of the region over the last century.', d['text'].strip
    assert_equal '735450245', d['user_uuid']
    assert_equal 'Mohamed Nanabhay', d['user_name']
    assert_equal 4, d['media_count']
    assert_equal '10156130657385246', d['object_id']
    assert_equal '27/10/2015', d['published'].strftime("%d/%m/%Y")
  end

  test "should create Facebook post from user photo URL 2" do
    m = create_media url: 'https://www.facebook.com/photo.php?fbid=1195161923843707&set=a.155912291102014.38637.100000497329098&type=3&theater'
    d = m.as_json
    assert_equal '100000497329098_1195161923843707', d['uuid']
    assert_equal '', d['text']
    assert_equal '100000497329098', d['user_uuid']
    assert_equal 'Kiko Loureiro', d['user_name']
    assert_equal 1, d['media_count']
    assert_equal '1195161923843707', d['object_id']
    # FIXME: This publishing date can be different for FB users who are in a different timezone.
    assert_equal '01/11/2015', d['published'].strftime("%d/%m/%Y")
  end

  test "should create Facebook post from user photo URL 3" do
    m = create_media url: 'https://www.facebook.com/photo.php?fbid=10155150801660195&set=p.10155150801660195&type=1&theater'
    d = m.as_json
    assert_equal '10155150801660195_10155150801660195', d['uuid']
    assert_equal '10155150801660195', d['user_uuid']
    assert_equal 'David Marcus', d['user_name']
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
    assert_match /^https/, d['picture']
    assert_kind_of Array, d['photos']
    assert_equal 0, d['media_count']
    assert_equal 0, d['photos'].size

    m = create_media url: 'https://www.facebook.com/johnwlai/posts/10101205465813840?pnref=story'
    d = m.as_json
    assert_match /^https/, d['picture']
    assert_kind_of Array, d['photos']
    assert_equal 2, d['media_count']
    assert_equal 0, d['photos'].size
  end

  test "should create Facebook post from Arabic user" do
    m = create_media url: 'https://www.facebook.com/ahlam.alialshamsi/posts/108561999277346?pnref=story'
    d = m.as_json
    assert_equal '100003706393630_108561999277346', d['uuid']
    assert_equal '100003706393630', d['user_uuid']
    assert_equal 'Ahlam Ali Al Shāmsi', d['user_name']
    assert_equal 0, d['media_count']
    assert_equal '108561999277346', d['object_id']
    assert_equal 'أنا مواد رافعة الآن الأموال اللازمة لمشروع مؤسسة خيرية، ودعم المحتاجين في غرب أفريقيا مساعدتي لبناء مكانا أفضل للأطفال في أفريقيا', d['text']
  end

  test "should create Facebook post from mobile URL" do
    m = create_media url: 'https://m.facebook.com/photo.php?fbid=1195161923843707&set=a.155912291102014.38637.100000497329098&type=3&theater'
    d = m.as_json
    assert_equal '100000497329098_1195161923843707', d['uuid']
    assert_equal '', d['text']
    assert_equal '100000497329098', d['user_uuid']
    assert_equal 'Kiko Loureiro', d['user_name']
    assert_equal 1, d['media_count']
    assert_equal '1195161923843707', d['object_id']
    # FIXME: This publishing date can be different for FB users who are in a different timezone.
    assert_equal '01/11/2015', d['published'].strftime("%d/%m/%Y")
  end

  test "should return author_url for Twitter post" do
    m = create_media url: 'https://twitter.com/TheConfMalmo_AR/status/765474989277638657'
    d = m.as_json
    assert_equal 'https://twitter.com/TheConfMalmo_AR', d['author_url']
  end

  test "should return author_url for Facebook post" do
    m = create_media url: 'https://www.facebook.com/photo.php?fbid=1195161923843707&set=a.155912291102014.38637.100000497329098&type=3&theater'
    d = m.as_json
    assert_equal 'http://facebook.com/100000497329098', d['author_url']
  end

  test "should parse Instagram link" do
    m = create_media url: 'https://www.instagram.com/p/BJwkn34AqtN/'
    d = m.as_json
    assert_equal 'megadeth', d['username']
    assert_equal 'item', d['type']
  end

  test "should parse Instagram profile" do
    m = create_media url: 'https://www.instagram.com/megadeth'
    d = m.as_json
    assert_equal 'megadeth', d['username']
    assert_equal 'profile', d['type']
    assert_equal 'megadeth', d['title']
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
    assert_equal 'New Quoted Pictures Everyday added a new photo.', d['description']
  end

  test "should parse Facebook photo post within an album url" do
    m = create_media url: 'https://www.facebook.com/ESCAPE.Egypt/photos/ms.c.eJxNk8d1QzEMBDvyQw79N2ZyaeD7osMIwAZKLGTUViod1qU~;DCBNHcpl8gfMKeR8bz2gH6ABlHRuuHYM6AdywPkEsH~;gqAjxqLAKJtQGZFxw7CzIa6zdF8j1EZJjXRgTzAP43XBa4HfFa1REA2nXugScCi3wN7FZpF5BPtaVDEBqwPNR60O9Lsi0nbDrw3KyaPCVZfqAYiWmZO13YwvSbtygCWeKleh9KEVajW8FfZz32qcUrNgA5wfkA4Xfh004x46d9gdckQt2xR74biSOegwIcoB9OW~_oVIxKML0JWYC0XHvDkdZy0oY5bgjvBAPwdBpRuKE7kZDNGtnTLoCObBYqJJ4Ky5FF1kfh75Gnyl~;Qxqsv.bps.a.1204090389632094.1073742218.423930480981426/1204094906298309/?type=3&theater'
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal 'Escape on Facebook', d['title']
    assert_equal 'Escape added a new photo.', d['description']
    assert_match /423930480981426/, d['picture']
    assert_equal '1204094906298309', d['object_id']
  end

  test "should parse Facebook pure text post url" do
    m = create_media url: 'https://www.facebook.com/dina.samak/posts/10153679232246949?pnref=story.unseen-section'
    d = m.as_json
    assert_equal 'Dina Samak on Facebook', d['title']
    assert_not_nil d['description']
    assert_not_nil d['picture']
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
    assert_not_nil d['picture']
    assert_not_nil d['published_at']
  end

  test "should parse Facebook event url" do
    m = create_media url: 'https://www.facebook.com/events/1090503577698748'
    d = m.as_json
    assert_equal 'Nancy Ajram in Stella Di Mare Music Festival on Facebook', d['title']
    assert_equal 'Nancy Ajram will be performing in Stella Di Mare, September 13th, 2016 in Egypt. For tickets and information please contact 19565.', d['description']
    assert_equal '25432690933', d['user_uuid']
    assert_equal '1090503577698748', d['object_id']
    assert_match /1090503577698748/, d['picture']
    assert_not_nil d['published_at']
  end

  test "should parse album post with a permalink" do
    m = create_media url: 'https://www.facebook.com/permalink.php?story_fbid=10154534111016407&id=54212446406'
    d = m.as_json
    assert_equal 'Mariano Rajoy Brey on Facebook', d['title']
    assert_equal 'item', d['type']
    assert_equal '10154534111016407', d['object_id']
    assert_match /54212446406/, d['picture']
    assert_not_nil d['published_at']
  end

  test "should parse Facebook gif photo url" do
    m = create_media url: 'https://www.facebook.com/quoted.pictures/posts/1095740107184121'
    d = m.as_json
    assert_equal 'New Quoted Pictures Everyday on Facebook', d['title']
    assert_not_nil d['description']
    assert_match /^https?:\/\/([^\.]+\.)?(giphy\.com|gph\.is)\/.*/, d['link']
    assert_match /.*giphy.gif$/, d['photos'].first
    assert_equal 1, d['media_count']
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

  test "should parse opengraph metatags" do
    m = create_media url: 'http://hacktoon.com/nerdson/2016/poker-planning'
    d = m.as_json
    assert_equal 'Poker planning - Hacktoon!', d['title']
    assert_equal 'Programming comics and digital culture', d['description']
    assert_equal '', d['published_at']
    assert_equal 'Karlisson M. Bezerra', d['username']
    assert_equal 'http://hacktoon.com/static/img/facebook-image.png', d['picture']
    assert_equal 'http://hacktoon.com', d['author_url']
  end

  test "should parse meta tags as fallback" do
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    m = create_media url: 'https://xkcd.com/1479', request: request
    d = m.as_json
    assert_equal 'xkcd: Troubleshooting', d['title']
    assert_equal 'xkcd: Troubleshooting', d['description']
    assert_equal '', d['published_at']
    assert_equal '', d['username']
    assert_equal 'http://xkcd.com', d['author_url']

    path = File.join(Rails.root, 'public', 'screenshots', 'http-xkcd-com-1479.png')
    assert File.exists?(path)
    assert_match /http:\/\/localhost\/screenshots\/http-xkcd-com-1479.png$/, d['picture']
  end

  test "should parse meta tags as fallback 2" do
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    m = create_media url: 'http://ca.ios.ba/', request: request
    d = m.as_json
    assert_equal 'CaioSBA', d['title']
    assert_equal 'Personal website of Caio Sacramento de Britto Almeida', d['description']
    assert_equal '', d['published_at']
    assert_equal '', d['username']
    assert_equal 'http://ca.ios.ba', d['author_url']

    path = File.join(Rails.root, 'public', 'screenshots', 'http-ca-ios-ba.png')
    assert File.exists?(path)
    assert_match /http:\/\/localhost\/screenshots\/http-ca-ios-ba.png$/, d['picture']
  end

  test "should parse Facebook photo on page album" do
    m = create_media url: 'https://www.facebook.com/southchinamorningpost/videos/vb.355665009819/10154584426664820/?type=2&theater'
    d = m.as_json
    assert_equal 'South China Morning Post SCMP on Facebook', d['title']
    assert_match /SCMP #FacebookLive/, d['description']
    assert_equal 'South China Morning Post SCMP', d['username']
    assert_match /355665009819/, d['picture']
    assert_equal 'http://facebook.com/355665009819', d['author_url']
    assert_not_nil d['published_at']
  end

  test "should not overwrite metatags with nil" do
    m = create_media url: 'https://meedan.checkdesk.org/node/2161'
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
    assert_equal 'Meedan', d['title']
    assert_match /team of designers, technologists and journalists/, d['description']
    assert_equal '', d['published_at']
    assert_equal '', d['username']
    assert_equal 'http://meedan.com/en/check/', m.url
    assert_equal 'http://meedan.com', d['author_url']
    assert_not_nil d['picture']
  end

  test "should parse valid link with blank spaces" do
    m = create_media url: ' https://twitter.com/anxiaostudio/status/788095322496995328 '
    d = m.as_json
    assert_equal 'https://twitter.com/anxiaostudio/status/788095322496995328', m.url
    assert_equal '@andybudd @jennifermjones cc @blinkpopshift', d['title']
    assert_equal '@andybudd @jennifermjones cc @blinkpopshift', d['description']
    assert_not_nil d['published_at']
    assert_equal 'anxiaostudio', d['username']
    assert_equal 'https://twitter.com/anxiaostudio', d['author_url']
    assert_not_nil d['picture']
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
    assert_match /.* points and .* comments so far on reddit/, d['description']
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
    assert_equal 'http://img.youm7.com/large/72016619556415g.jpg', d['picture']
  end

  test "should not store the picture address if it was not taken" do
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    Smartshot::Screenshot.any_instance.stubs(:take_screenshot!).returns(false)
    m = create_media url: 'http://xkcd.com/448/', request: request
    d = m.as_json
    assert_equal 'xkcd: Good Morning', d['title']
    assert_equal 'xkcd: Good Morning', d['description']
    assert_equal '', d['published_at']
    assert_equal '', d['username']
    assert_equal 'http://xkcd.com', d['author_url']
    assert_equal '', d['picture']
    Smartshot::Screenshot.any_instance.unstub(:take_screenshot!)
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
    expected = 'https://www.facebook.com/democrats/videos/10154268929856943'
    variations = %w(
      https://www.facebook.com/democrats/videos/10154268929856943/
      https://www.facebook.com/democrats/posts/10154268929856943/
    )
    variations.each do |url|
      media = Media.new(url: url)
      media.as_json
      assert_equal expected, media.url
    end
  end

  test "should get canonical URL from facebook object 2" do
    expected = 'https://www.facebook.com/54212446406/photos/a.10154534110871407.1073742048.54212446406/10154534111016407?type=3'
    variations = %w(
      https://www.facebook.com/permalink.php?story_fbid=10154534111016407&id=54212446406
      https://www.facebook.com/54212446406/photos/a.10154534110871407.1073742048.54212446406/10154534111016407/?type=3
      https://www.facebook.com/54212446406/photos/a.10154534110871407.1073742048.54212446406/10154534111016407?type=3
    )
    variations.each do |url|
      media = Media.new(url: url)
      media.as_json
      assert_equal expected, media.url
    end
  end

  test "should parse facebook url with a photo album" do
    expected = {
      url: 'https://www.facebook.com/Classic.mou/photos/a.136991166478555.1073741828.136985363145802/613639175480416?type=3',
      title: 'Classic on Facebook',
      description: 'Classic added a new photo.',
      username: 'Classic',
      author_url: 'http://facebook.com/136985363145802',
      picture: 'https://graph.facebook.com/136985363145802/picture'
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
    assert_equal 'salmaeldaly', data['username']
    assert_equal 'https://twitter.com/salmaeldaly', data['author_url']
    assert_not_nil data['picture']
  end

  test "should parse Facebook live post from mobile URL" do
    m = create_media url: 'https://m.facebook.com/story.php?story_fbid=10154584426664820&id=355665009819%C2%ACif_t=live_video%C2%ACif_id=1476846578702256&ref=bookmarks'
    data = m.as_json
    assert_equal 'https://www.facebook.com/southchinamorningpost/videos/10154584426664820', m.url
    assert_equal 'South China Morning Post SCMP on Facebook', data['title']
    assert_match /SCMP #FacebookLive amid chaotic scenes in #HongKong Legco/, data['description']
    assert_not_nil data['published_at']
    assert_equal 'South China Morning Post SCMP', data['username']
    assert_equal 'http://facebook.com/355665009819', data['author_url']
    assert_equal 'https://graph.facebook.com/355665009819/picture', data['picture']
  end

  test "should parse Facebook live post" do
    m = create_media url: 'https://www.facebook.com/cbcnews/videos/10154783484119604/'
    data = m.as_json
    assert_equal 'https://www.facebook.com/cbcnews/videos/10154783484119604', m.url
    assert_equal 'CBC News on Facebook', data['title']
    assert_equal 'Live now: This is the National for Monday, Oct. 31, 2016.', data['description']
    assert_not_nil data['published_at']
    assert_equal 'CBC News', data['username']
    assert_equal 'http://facebook.com/5823419603', data['author_url']
    assert_equal 'https://graph.facebook.com/5823419603/picture', data['picture']
  end

  test "should parse Facebook removed live post" do
    m = create_media url: 'https://www.facebook.com/LiveNationTV/videos/1817191221829045/'
    data = m.as_json
    assert_equal 'https://www.facebook.com/LiveNationTV/videos/1817191221829045', m.url
    assert_equal 'Not Identified on Facebook', data['title']
    assert_equal '', data['description']
    assert_equal '', data['published_at']
    assert_equal 'Not Identified', data['username']
    assert_equal 'http://facebook.com/1600067986874704', data['author_url']
    assert_equal 'https://graph.facebook.com/1600067986874704/picture', data['picture']
  end

  test "should parse Facebook livemap" do
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    m = create_media url: 'https://www.facebook.com/livemap/#@37.777053833008,-122.41587829590001,4z', request: request
    data = m.as_json
    assert_equal 'https://www.facebook.com/livemap/', m.url
    assert_equal 'Not Identified on Facebook', data['title']
    assert_equal 'Explore live videos from around the world.', data['description']
    assert_not_nil data['published_at']
    assert_equal 'Not Identified', data['username']
    assert_equal 'http://facebook.com/', data['author_url']
    assert_equal '', data['picture']
  end

  test "should parse Facebook event post" do
    m = create_media url: 'https://www.facebook.com/events/364677040588691/permalink/376287682760960/?ref=1&action_history=null'
    data = m.as_json
    assert_equal 'https://www.facebook.com/zawyacinema/photos/gm.376287682760960/1184539554945737?type=3', m.url
    assert_equal 'Zawya on Facebook', data['title']
    assert_match /توضيح عن عرض فيلم الحرّيف/, data['description']
    assert_not_nil data['published_at']
    assert_equal 'Zawya', data['username']
    assert_match /#{data['user_uuid']}/, data['author_url']
    assert_match /#{data['user_uuid']}/, data['picture']
  end

  test "should parse Facebook event post 2" do
    m = create_media url: 'https://www.facebook.com/events/364677040588691/permalink/379973812392347/?ref=1&action_history=null'
    data = m.as_json
    assert_equal 'https://www.facebook.com/events/364677040588691/permalink/379973812392347', m.url
    assert_equal 'Hema Elsyaad on Facebook', data['title']
    assert_equal 'مفيش حاجة قريب ل ا. داواد عبدالسيد ؟!!', data['description']
    assert_not_nil data['published_at']
    assert_equal 'Hema Elsyaad', data['username']
    assert_match /#{data['user_uuid']}/, data['author_url']
    assert_match /#{data['user_uuid']}/, data['picture']
  end

  test "should parse url without body" do
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    m = create_media url: 'http://asdfasdf.com/', request: request
    data = m.as_json
    assert_equal 'http://asdfasdf.com/', m.url
    assert_equal '', data['title']
    assert_equal '', data['description']
    assert_equal '', data['published_at']
    assert_equal '', data['username']
    assert_equal 'http://asdfasdf.com', data['author_url']
    assert_equal '', data['picture']
  end
end
