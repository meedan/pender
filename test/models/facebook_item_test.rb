require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class FacebookItemTest < ActiveSupport::TestCase
  test "should get canonical URL parsed from facebook html when it is relative" do
    relative_url = '/dina.samak/posts/10153679232246949'
    url = "https://www.facebook.com#{relative_url}"
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML("<meta property='og:url' content='#{relative_url}'>"))
    Media.any_instance.stubs(:follow_redirections)
    m = create_media url: url
    assert_equal url, m.url
    Media.any_instance.unstub(:get_html)
    Media.any_instance.unstub(:follow_redirections)
  end

  test "should get canonical URL parsed from facebook html when it is a page" do
    canonical_url = 'https://www.facebook.com/CyrineOfficialPage/posts/10154332542247479'
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML("<meta property='og:url' content='#{canonical_url}'>"))
    Media.any_instance.stubs(:follow_redirections)
    Media.stubs(:validate_url).with(canonical_url).returns(true)
    m = create_media url: 'https://www.facebook.com/CyrineOfficialPage/posts/10154332542247479?pnref=story.unseen-section'
    assert_equal canonical_url, m.url
    Media.any_instance.unstub(:get_html)
    Media.any_instance.unstub(:follow_redirections)
    Media.unstub(:validate_url)
  end

  test "should get canonical URL from facebook object 3" do
    url = 'https://www.facebook.com/54212446406/photos/a.397338611406/10157431603156407/?type=3&theater'
    media = Media.new(url: url)
    media.as_json({ force: 1 })
    assert_match 'https://www.facebook.com/54212446406/photos/a.397338611406/10157431603156407', media.url
  end

  test "should parse facebook url with a photo album post pattern" do
    media = Media.new url: 'https://www.facebook.com/Classic.mou/photos/1630270703817253'
    data = media.as_json
    assert !data['author_url'].blank?
    assert_match 'Classic', data['title']
    assert_match 'Classic.mou', data['username']
    assert_match 'Classic', data['author_name']
  end

  { a_pattern: 'https://www.facebook.com/Classic.mou/photos/a.136991166478555/1494688604042131',
    pcb_pattern: 'https://www.facebook.com/Classic.mou/photos/pcb.613639338813733/613639175480416/'
  }.each do |pattern, url|
    test "should parse facebook url with a photo album #{pattern}" do
      expected = {
        title: 'Classic',
        username: 'Classic.mou',
      }.with_indifferent_access

      media = Media.new url: url
      data = media.as_json
      assert !data['author_url'].blank?
      expected.each do |key, value|
        assert_match value, data[key], "Expected #{key} '#{data[key]}' to match #{value} on #{url}"
      end
    end
  end

  test "should parse Facebook live post from mobile URL" do
    url = 'https://m.facebook.com/story.php?story_fbid=10154584426664820&id=355665009819%C2%ACif_t=live_video%C2%ACif_id=1476846578702256&ref=bookmarks'
    id = Media.get_id url
    m = create_media url: url
    data = m.as_json
    assert !data['title'].blank?
    assert_match 'facebook.com/355665009819', data['author_url']
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
  end

  test "should create Facebook post from mobile URL" do
    m = create_media url: 'https://m.facebook.com/KIKOLOUREIROofficial/photos/a.10150618138397252/10152555300292252/?type=3&theater'
    data = m.as_json
    assert !data['title'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
  end

  test "should parse Facebook pure text post url" do
    Media.any_instance.stubs(:get_crowdtangle_data)
    url = 'https://www.facebook.com/dina.samak/posts/10153679232246949?pnref=story.unseen-section'
    html = "<title id='pageTitle'>Dina Samak | Facebook</title>
            <div data-testid='post_message' class='_5pbx userContent'>
            <p>إذا كنت تعرف هيثم محمدين كما أعرفه فمن المؤكد انك قد استمتعت بقدرته الرائعة على الحكي..</p>
           </div>"
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML(html))
    Media.any_instance.stubs(:follow_redirections)
    m = create_media url: url
    data = m.as_json
    assert_match /Dina Samak/, data['title']
    Media.any_instance.unstub(:get_html)
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_crowdtangle_data)
  end

  test "should parse Facebook live post" do
    url = 'https://www.facebook.com/cbcnews/videos/10154783484119604/'
    id = Media.get_id url
    m = create_media url: url
    data = m.as_json
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
    assert_match /https:\/\/www.facebook.com\/(5823419603|cbcnews)\/(videos|posts)\/(the-national-live\/)?10154783484119604/, m.url
    assert !data['title'].blank?
    assert_match 'cbcnews', data['username']
    assert_match /facebook.com\/(5823419603|cbcnews)/, data['author_url']
  end

  test "should parse Facebook removed live post" do
    url = 'https://www.facebook.com/teste637621352/posts/1538843716180215'
    id = Media.get_id url
    m = create_media url: url
    data = m.as_json
    assert_equal 'https://www.facebook.com/teste637621352/posts/1538843716180215', m.url
    assert_match 'teste637621352', data['username']
    assert !data['title'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
  end

  test "should parse Facebook livemap" do
    variations = %w(
      https://www.facebook.com/livemap/#@-12.991858482361014,-38.521747589110994,4z
      https://www.facebook.com/live/map/#@37.777053833008,-122.41587829590001,4z
      https://www.facebook.com/live/discover/map/#@37.777053833008,-122.41587829590001,4z
    )

    variations.each do |url|
      m = create_media url: url
      data = m.as_json
      assert_match /facebook\.com/, m.url
      assert !data['title'].blank?
    end
  end

  test "should parse Facebook event post" do
    doc = '<div id="event_header_primary">' \
      '<div class="_5gmv">' \
        '<div class="clearfix _7wy" id="title_subtitle">' \
          '<div class="_42ef">' \
            '<div class="_5gmw">' \
              '<h1 id="seo_h1_tag" class="_5gmx" data-testid="event-permalink-event-name">Zawya\'s Tribute to Mohamed Khan | موعد مع خان</h1>' \
              '<div class="_5gnb">Public · Hosted by <span class="fwb"><a class="profileLink" href="https://www.facebook.com/zawyacinema/?fref=tag">Zawya</a></span>' \
              '</div>' \
            '</div>' \
          '</div>' \
        '</div>' \
      '</div>' \
    '</div>'

    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML(doc))
    m = create_media url: 'https://www.facebook.com/events/364677040588691/permalink/376287682760960/?ref=1&action_history=null'
    data = m.as_json
    assert_match /https:\/\/www.facebook\.com\/events\/(364677040588691|zawya)/, m.url
    assert_not_nil data['published_at']
    assert !data['title'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
    assert_equal 'Zawya', data['author_name']
    assert_equal 'https://www.facebook.com/zawyacinema/?fref=tag', data['author_url']
    Media.any_instance.unstub(:get_html)
  end

  test "should parse Facebook event url" do
    m = create_media url: 'https://www.facebook.com/events/1090503577698748'
    data = m.as_json
    assert !data['title'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
  end

  test "should parse Facebook video url from a page" do
    m = create_media url: 'https://www.facebook.com/144585402276277/videos/1127489833985824'
    data = m.as_json
    assert !data['title'].blank?, 'Expected title to not be blank'
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
  end

  test "should parse Facebook video url from a page with another url pattern" do
    m = create_media url: 'https://www.facebook.com/democrats/videos/10154268929856943'
    data = m.as_json
    assert !data['title'].blank?
    assert_equal 'item', data['type']
    assert_not_nil data['picture']
  end

  test "should parse Facebook video url from a profile" do
    m = create_media url: 'https://www.facebook.com/edwinscott143/videos/vb.737361619/10154242961741620/?type=2&theater'
    data = m.as_json
    assert !data['title'].blank?
    assert_equal 'item', data['type']
    assert_not_nil data['author_picture']
  end

  test "should parse Facebook video on page album" do
    url = 'https://www.facebook.com/scmp/videos/10154584426664820'
    id = Media.get_id url
    m = create_media url: url
    data = m.as_json
    assert_match /(south china morning post|scmp)/, data['title'].downcase
    assert_match /facebook.com\/(355665009819|scmp)/, data['author_url']
  end

  test "should parse Facebook gif photo url" do
    m = create_media url: 'https://www.facebook.com/quoted.pictures/posts/1095740107184121'
    data = m.as_json
    assert !data['title'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
  end

  test "should parse album post with a permalink" do
    url = 'https://www.facebook.com/permalink.php?story_fbid=10154534111016407&id=54212446406'
    id = Media.get_id url
    m = create_media url: url
    data = m.as_json
    assert !data['title'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
  end

  test "should parse facebook user post" do
    url = 'https://www.facebook.com/dina.hawary/posts/10158416884740321'
    id = Media.get_id url
    m = create_media url: url
    data = m.as_json
    assert_equal 'item', data['type']
    assert_equal 'facebook', data['provider']
  end

  test "should parse facebook url with colon mark" do
    url = 'https://www.facebook.com/Classic.mou/posts/666508790193454:0'
    id = Media.get_id url
    m = create_media url: url
    data = m.as_json
    assert_equal 'item', data['type']
    assert_equal 'facebook', data['provider']
  end

  test "should parse Facebook post from media set" do
    url = 'https://www.facebook.com/media/set?set=a.10154534110871407.1073742048.54212446406&type=3'
    m = create_media url: url
    data = m.as_json
    assert_match '54212446406_10154534110871407', data['uuid']
    assert_match '54212446406', data['user_uuid']
    assert_match '10154534110871407', data['object_id']
    assert_match url, m.url
  end

  test "should support facebook pattern with pg" do
    m = create_media url: 'https://www.facebook.com/pg/Mariano-Rajoy-Brey-54212446406/photos/?tab=album&album_id=10154534110871407'
    data = m.as_json
    assert_equal 'item', data['type']
    assert_match '54212446406_10154534110871407', data['uuid']
    assert !data['title'].blank?
    assert_match '54212446406', data['user_uuid']
    assert_match '10154534110871407', data['object_id']
    assert_match /https:\/\/www.facebook.com\/.*Mariano-Rajoy-Brey-54212446406/, m.url
    assert_equal 'item', data['type']
    assert_equal 'facebook', data['provider']
  end

  test "should support facebook pattern with album" do
    m = create_media url: 'https://www.facebook.com/album.php?fbid=10154534110871407&id=54212446406&aid=1073742048'
    data = m.as_json
    assert_match '10154534110871407_10154534110871407', data['uuid']
    assert_nil data['error']
    assert_match 'https://www.facebook.com/media/set?set=a.10154534110871407', m.url
  end

  test "should get facebook data from original_url when url fails" do
    Media.any_instance.stubs(:url).returns('https://www.facebook.com/Mariano-Rajoy-Brey-54212446406/photos')
    Media.any_instance.stubs(:original_url).returns('https://www.facebook.com/pg/Mariano-Rajoy-Brey-54212446406/photos/?tab=album&album_id=10154534110871407')
    m = create_media url: 'https://www.facebook.com/pg/Mariano-Rajoy-Brey-54212446406/photos'
    data = m.as_json
    assert_match '_10154534110871407', data['uuid']
    assert !data['title'].blank?
    assert_match '54212446406', data['user_uuid']
    assert_match '10154534110871407', data['object_id']
    assert_equal 'item', data['type']
    assert_equal 'facebook', data['provider']
    Media.any_instance.unstub(:url)
    Media.any_instance.unstub(:original_url)
  end

  test "should store oembed data of a facebook post" do
    m = create_media url: 'https://www.facebook.com/nostalgia.y/photos/a.508939832569501.1073741829.456182634511888/942167619246718/?type=3&theater'
    m.as_json
    m.data.delete(:error)
    m.send(:data_from_oembed_item)
    assert m.data['raw']['oembed'].is_a? Hash
    assert_match /facebook.com/, m.data['oembed']['provider_url']
    assert_equal "facebook", m.data['oembed']['provider_name'].downcase
  end

  test "should store oembed data of a facebook page" do
    m = create_media url: 'https://www.facebook.com/pages/Meedan/105510962816034?fref=ts'
    m.as_json
    m.data.delete(:error)
    m.send(:data_from_oembed_item)
    assert m.data['raw']['oembed'].is_a?(Hash), "Expected #{m.data['raw']['oembed']} to be a Hash"
    assert !m.data['oembed']['author_name'].blank?
    assert !m.data['oembed']['title'].blank?
  end

  test "should parse Facebook post from page photo" do
    m = create_media url: 'https://www.facebook.com/quoted.pictures/photos/a.128828073875334.28784.128791873878954/1096134023811396/?type=3&theater'
    data = m.as_json
    assert !data['title'].blank?
    assert_match 'quoted.pictures', data['username']
    assert_match /quoted.pictures/, data['author_name'].downcase
    assert !data['author_url'].blank?
    assert_equal 'item', data['type']
    assert_equal 'facebook', data['provider']
  end

  test "should parse facebook url without identified pattern as item" do
    url = 'https://www.facebook.com/Bimbo.Memories/photos/pb.235404669918505.-2207520000.1481570271./1051597428299221/?type=3&theater'
    m = create_media url: url
    data = m.as_json
    assert_equal 'item', data['type']
    assert_match /Bimbo/, data['title']
    assert_not_nil data['description']
    assert_not_nil data['published_at']
    assert_match 'Bimbo', data['username']
    assert_match /facebook.com\/(235404669918505|Bimbo.Memories)/, data['author_url']
  end

  test "should parse Facebook photo post within an album url" do
    url = 'https://www.facebook.com/ESCAPE.Egypt/photos/ms.c.eJxNk8d1QzEMBDvyQw79N2ZyaeD7osMIwAZKLGTUViod1qU~;DCBNHcpl8gfMKeR8bz2gH6ABlHRuuHYM6AdywPkEsH~;gqAjxqLAKJtQGZFxw7CzIa6zdF8j1EZJjXRgTzAP43XBa4HfFa1REA2nXugScCi3wN7FZpF5BPtaVDEBqwPNR60O9Lsi0nbDrw3KyaPCVZfqAYiWmZO13YwvSbtygCWeKleh9KEVajW8FfZz32qcUrNgA5wfkA4Xfh004x46d9gdckQt2xR74biSOegwIcoB9OW~_oVIxKML0JWYC0XHvDkdZy0oY5bgjvBAPwdBpRuKE7kZDNGtnTLoCObBYqJJ4Ky5FF1kfh75Gnyl~;Qxqsv.bps.a.1204090389632094.1073742218.423930480981426/1204094906298309/?type=3&theater'
    id = Media.get_id url
    m = create_media url: url
    data = m.as_json
    assert_equal 'item', data['type']
    assert_match /escape/, data['title'].downcase
    assert_match /1204094906298309/, data['uuid']
  end

  test "should parse photo in a photo album" do
    url = 'https://www.facebook.com/nostalgia.y/photos/pb.456182634511888.-2207520000.1484079948./928269767303170/?type=3&theater'
    id = Media.get_id url
    m = create_media url: url
    data = m.as_json
    assert_equal 'item', data['type']
    assert_equal 'facebook', data['provider']
    assert_match /nostalgia/, data['title'].downcase
    assert_not_nil data['published_at']
    assert_match 'nostalgia.y', data['username']
    assert_match /facebook.com\/(456182634511888|nostalgia.y)/, data['author_url']
  end

  test "should create Facebook post from page photo URL" do
    m = create_media url: 'https://www.facebook.com/teste637621352/photos/a.754851877912740.1073741826.749262715138323/896869113711015/?type=3'
    data = m.as_json
    assert_match /896869113711015/, data['uuid']
    assert_match 'facebook.com/teste637621352', data['author_url']
    assert_match 'teste637621352', data['username']
    assert_match '896869113711015', data['object_id']
  end

  test "should create Facebook post from page photos URL" do
    m = create_media url: 'https://www.facebook.com/teste637621352/posts/1028795030518422'
    data = m.as_json
    assert_match /1028795030518422/, data['uuid']
    assert !data['title'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
  end

  test "should create Facebook post from user photos URL" do
    m = create_media url: 'https://www.facebook.com/nanabhay/posts/10156130657385246?pnref=story'
    data = m.as_json
    assert_match '10156130657385246', data['uuid']
    assert !data['title'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
  end

  test "should parse Facebook post from user photo URL" do
    url = 'https://www.facebook.com/photo.php?fbid=10155150801660195&set=p.10155150801660195&type=1&theater'
    id = Media.get_id url
    m = create_media url: url
    data = m.as_json
    assert_match '10155150801660195_10155150801660195', data['uuid']
    assert_match '10155150801660195', data['user_uuid']
    assert_match '10155150801660195', data['object_id']
    assert !data['title'].blank?
  end

  tests = YAML.load_file(File.join(Rails.root, 'test', 'data', 'fbposts.yml'))
  tests.each do |url, text|
    test "should get text from Facebook user post from URL '#{url}'" do
      Media.any_instance.stubs(:get_crowdtangle_data)
      Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML("<meta name='description' content='#{text}'>"))
      Media.any_instance.stubs(:follow_redirections)

      m = create_media url: url
      data = m.as_json
      assert_match text, data['text'].gsub(/\s+/, ' ').strip
      Media.any_instance.unstub(:get_html)
      Media.any_instance.unstub(:follow_redirections)
      Media.any_instance.unstub(:get_crowdtangle_data)
    end
  end

  test "should create Facebook post with picture and photos" do
    url = 'https://www.facebook.com/teste637621352/posts/1028795030518422'
    id = Media.get_id url
    m = create_media url: url
    data = m.as_json
    assert !data['title'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']

    url = 'https://www.facebook.com/teste637621352/posts/1035783969819528'
    id = Media.get_id url
    m = create_media url: url
    data = m.as_json
    assert !data['title'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']

    url = 'https://www.facebook.com/teste637621352/posts/2194142813983632'
    id = Media.get_id url
    m = create_media url: url
    data = m.as_json
    assert !data['title'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
  end

  test "should get normalized URL from crowdtangle" do
    url = 'https://www.facebook.com/quoted.pictures/posts/3424788280945947'
    m = create_media url: url
    data = m.as_json

    url = 'https://www.facebook.com/quoted.pictures/photos/a.525451984212939/3424788187612623?type=3'
    m = create_media url: url
    data = m.as_json
    assert_equal url, data['url']
  end
  
  test "should return item as oembed" do
    url = 'https://www.facebook.com/pages/Meedan/105510962816034?fref=ts'
    m = create_media url: url
    data = Media.as_oembed(m.as_json, "http://pender.org/medias.html?url=#{url}", 300, 150)
    assert !data['title'].blank?
    assert_match 'https://www.facebook.com/pages/Meedan/105510962816034', data['author_url']
    assert_equal 'facebook', data['provider_name']
    assert_equal 'http://www.facebook.com', data['provider_url']
    assert_equal 300, data['width']
    assert_equal 150, data['height']
    assert_equal '<iframe src="http://pender.org/medias.html?url=https://www.facebook.com/pages/Meedan/105510962816034?fref=ts" width="300" height="150" scrolling="no" border="0" seamless>Not supported</iframe>', data['html']
  end

  test "should return item as oembed when data is not on cache" do
    url = 'https://www.facebook.com/photo.php?fbid=265901254902229&set=pb.100044470688234.-2207520000..&type=3'
    m = create_media url: url
    data = Media.as_oembed(nil, "http://pender.org/medias.html?url=#{url}", 300, 150, m)
    assert !data['title'].blank?
    assert !data['author_url'].blank?
    assert_equal 'facebook', data['provider_name']
    assert_equal 'http://www.facebook.com', data['provider_url']
    assert_equal 300, data['width']
    assert_equal 150, data['height']
    assert_equal "<iframe src=\"http://pender.org/medias.html?url=#{url}\" width=\"300\" height=\"150\" scrolling=\"no\" border=\"0\" seamless>Not supported</iframe>", data['html']
    assert_not_nil data['thumbnail_url']
  end

  test "should return item as oembed when data is on cache and raw key is missing" do
    url = 'https://www.facebook.com/photo/?fbid=264562325036122&set=pb.100044470688234.-2207520000..'
    m = create_media url: url
    json_data = m.as_json
    json_data.delete('raw')
    data = Media.as_oembed(json_data, "http://pender.org/medias.html?url=#{url}", 300, 150)
    assert !data['title'].blank?
    assert !data['author_url'].blank?
    assert_equal 'facebook', data['provider_name']
    assert_equal 'http://www.facebook.com', data['provider_url']
    assert_equal 300, data['width']
    assert_equal 150, data['height']
    assert_equal "<iframe src=\"http://pender.org/medias.html?url=#{url}\" width=\"300\" height=\"150\" scrolling=\"no\" border=\"0\" seamless>Not supported</iframe>", data['html']
    assert_not_nil data['thumbnail_url']
  end

  test "should return item as oembed when the page has oembed url" do
    url = 'https://www.facebook.com/teste637621352/posts/1028416870556238'
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML("<meta property='og:title' content='Teste'>"))
    m = create_media url: url
    data = Media.as_oembed(m.as_json, "http://pender.org/medias.html?url=#{url}", 300, 150, m)
    assert_match /teste/, data['title'].downcase
    assert_match /facebook.com\//, data['author_url']
    assert_equal 'facebook', data['provider_name']
    assert_match /https?:\/\/www.facebook.com/, data['provider_url']
    Media.any_instance.unstub(:get_html)
  end

  test "should not use Facebook embed if is a link to redirect" do
    url = 'https://l.facebook.com/l.php?u=https://hindi.indiatvnews.com/paisa/business-1-07-cr-new-taxpayers-added-dropped-filers-down-at-25-22-lakh-in-fy18-630914&h=AT1WAU-mDHKigOgFNrUsxsS2doGO0_F5W9Yck7oYUx-IsYAHx8JqyHwO02-N0pX8UOlcplZO50px8mkTA1XNyKig8Z2CfX6t3Sh0bHtO9MYPtWqacCm6gOXs5lbC6VGMLjDALNXZ6vg&s=1'

    m = create_media url: url
    data = m.as_json
    assert !data['title'].blank?
    assert_equal '', data['html']
  end

  test "should get image from original post if is a shared content" do
    original_url = 'https://www.facebook.com/dcc1968/posts/1538584976252118'
    url = 'https://www.facebook.com/danielafeitosa/posts/1862242233833668'
    doc = '<div class="_5pcr userContentWrapper">'\
      '<div class="mtm _5pcm">'\
        '<div class="_5pcp _5lel _2jyu _232_" id="feed_subtitle_1538584976252118:9:0" data-testid="story-subtitle">'\
          '<span class="z_c3pyo1brp">'\
            '<span class="fsm fwn fcg">'\
              '<a rel="theater" ajaxify="/dcc1968/photos/a.481675875276372/1538581552919127/" class="_5pcq" href="/dcc1968/photos/a.481675875276372/1538581552919127/" target="">'\
                '<abbr data-utime="1526292684" title="Monday, May 14, 2018 at 3:11 AM" data-shorten="1" class="_5ptz">'\
                  '<span class="timestampContent">May 14, 2018</span>'\
                '</abbr></a></span></span></div></div></div>'
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML(doc))
    id = Media.get_id(url)
    m = create_media url: url.to_s
    data = m.as_json
    assert_match /facebook.com\/dcc1968/, data.dig('original_post')
  end

  #commented until #8563 be fixed
  # test "should not get original post if it's already parsing the original post" do
  #   m = create_media url: 'https://www.facebook.com/groups/1863694297275556/permalink/2193768444268138/'
  #   data = m.as_json
  #   original_post = data.dig('original_post')
  #   assert_not_nil original_post

  #   original = Media.new url: original_post
  #   assert_nil original.as_json['original_post']
  # end

  test "should have external id for post" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML("<meta property='og:url' content='https://www.facebook.com/ironmaiden/posts/10156071020577051'>"))
    m = create_media url: 'https://www.facebook.com/ironmaiden/posts/10156071020577051'
    data = m.as_json
    assert_match '10156071020577051', data['external_id']
    Media.any_instance.unstub(:doc)
  end

  test "should parse Facebook category page" do
    m = create_media url: 'https://www.facebook.com/pages/category/Society---Culture-Website/PoporDezamagit/photos/'
    data = m.as_json
    assert !data['title'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
  end

  test "should return empty html for deleted posts" do
    Media.any_instance.stubs(:get_html).returns(nil)
    urls = ['https://www.facebook.com/danielafeitosa/posts/2074906892567200', 'https://www.facebook.com/caiosba/posts/8457689347638947']
    urls.each do |url|
      m = create_media url: url
      data = m.as_json
      assert_equal '', data[:html]
    end
    Media.any_instance.unstub(:get_html)
  end

  test "should add login required error and return empty html and description" do
    html = "<title id='pageTitle'>Log in or sign up to view</title><meta property='og:description' content='See posts, photos and more on Facebook.'>"
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML(html))
    Media.any_instance.stubs(:follow_redirections)

    m = create_media url: 'https://www.facebook.com/caiosba/posts/3588207164560845'
    data = m.as_json
    assert_equal 'Login required to see this profile', data[:error][:message]
    assert_equal LapisConstants::ErrorCodes::const_get('LOGIN_REQUIRED'), data[:error][:code]
    assert_equal m.url, data[:title]
    assert_equal '', data[:description]
    assert_equal '', data[:html]
    Media.any_instance.unstub(:get_html)
    Media.any_instance.unstub(:follow_redirections)
  end

  test "should get the group name when parsing group post" do
    url = 'https://www.facebook.com/groups/memetics.hacking/permalink/1580570905320222/'
    m = Media.new url: url
    data = m.as_json
    assert_no_match "Not Identified", data['title']
    assert_match 'permalink/1580570905320222/', data['url']
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
  end

  test "should parse page post date from public page profile" do
    url = 'https://www.facebook.com/nytimes/posts/10152617171394999'
    doc = '<a class="_5pcq" href="/nytimes/posts/10152617171394999"><abbr data-utime="1614206307" title="Wednesday, February 24, 2021 at 22:38 PM" class="_5ptz timestamp livetimestamp"><span class="timestampContent">February 24, 2021</span></abbr></a>'
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML(doc))
    m = Media.new url: url
    data = m.as_json
    assert_match /2021-02-24T22:38:27/, data['published_at']
    Media.any_instance.unstub(:get_html)
  end

  test "should parse post date from public person profile" do
    url = 'https://www.facebook.com/marc.smolowitz/posts/10158161767684331'
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML('<div class="_5pcr userContentWrapper"><script>{\"publish_time\":1599260261}</script></div>'))
    m = Media.new url: url
    data = m.as_json
    assert_equal '2020-09-04T22:57:41.000+00:00', data['published_at']

    url = 'https://www.facebook.com/julien.caidos/posts/10158477528272170'
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML('<div class="_5pcr userContentWrapper"><abbr data-utime="1599130881"><span class="timestampContent">4 de setembro de 2020</span></abbr></div>'))
    m = Media.new url: url
    data = m.as_json
    assert_equal '2020-09-03T11:01:21.000+00:00', data['published_at']

    url = 'https://www.facebook.com/marc.smolowitz/posts/10158557445564331'
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML('<div class="_5pcr userContentWrapper"><div id="MPhotoContent" class="timestampContent" data-utime="1599267148"><abbr><span>5 de setembro de 2020</span></abbr></div></div>'))
    m = Media.new url: url
    assert_equal Time.at(1599267148), m.get_facebook_published_time_from_html
    Media.any_instance.unstub(:get_html)
  end

  test "should parse post from public group" do
    Media.any_instance.stubs(:get_crowdtangle_data)
    html = '{"__bbox":{"result":{"data":{"group":{"description_with_entities":{"text":"A gathering for those interested in exploring belief systems."}},"node":{"comet_sections":{"content":{"story":{"comet_sections":{"message":{"__typename":"CometFeedStoryDefaultMessageRenderingStrategy","story":{"is_text_only_story":true,"message":{"color_ranges":[],"text":"Welcome! This group is a gathering for \nthose interested in exploring belief systems"}}'
    url = 'https://www.facebook.com/groups/memetics.hacking/permalink/1580570905320222/'
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML(html))
    m = Media.new url: url
    data = m.as_json
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
    assert !data['title'].blank?
    assert_match /This group is a gathering for those interested in exploring belief systems/, data['description']
    Media.any_instance.unstub(:get_crowdtangle_data)
    Media.any_instance.unstub(:get_html)
  end

  test "should get full text of Facebook post" do
    Media.any_instance.stubs(:get_crowdtangle_data)
    url = 'https://www.facebook.com/ironmaiden/posts/10157024746512051'
    html = "<div data-testid='post_message' class='_5pbx userContent'>
          <p>Legacy of the Beast Touring Update 2020/21</p>
          <p> I hope you and your loved ones are staying safe and well, wherever you may be, and my continued thanks to you all for bearing with us so patiently.</p>
          <p> Due to the continuing health issues Worldwide around Covid-19 we regretfully inform you that Iron Maiden will now not be playing any concerts until June 2021.</p>
          <p> However, we are now in a position to give you details of our touring plans in respect to those shows we had hoped to play this year.</p>
       </div>"
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML(html))
    Media.any_instance.stubs(:follow_redirections)
    m = Media.new url: url
    data = m.as_json
    assert_match /However, we are now in a position to give you details of our touring plans in respect to those shows we had hoped to play this year/, data['description']
    Media.any_instance.unstub(:get_html)
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_crowdtangle_data)
  end

  test "should not change url when redirected to login page" do
    url = 'https://www.facebook.com/ugmhmyanmar/posts/2850282508516442'
    redirection_to_login_page = 'https://www.facebook.com/login/'
    response = 'mock'; response.stubs(:code).returns('302')
    response.stubs(:header).returns({ 'location' => redirection_to_login_page })
    response_login_page = 'mock'; response_login_page.stubs(:code).returns('200')
    Media.stubs(:request_url).with(url, 'Get').returns(response)
    Media.stubs(:request_url).with(redirection_to_login_page, 'Get').returns(response_login_page)
    Media.stubs(:request_url).with(redirection_to_login_page + '?next=https%3A%2F%2Fwww.facebook.com%2Fugmhmyanmar%2Fposts%2F2850282508516442', 'Get').returns(response_login_page)
    m = create_media url: url
    assert_equal url, m.url
    Media.unstub(:request_url)
  end

  test "should get owner id from info on script tag" do
    Media.any_instance.stubs(:get_crowdtangle_data)
    url = 'https://www.facebook.com/AsiNoPresidente/photos/a.457685231695418/861850457945558?type=3&theater'
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML('<script>{"data":{"__isMedia":"Photo","id":"861850457945558","owner":{"__typename":"Page","id":"456567378473870","__isProfile":"Page"}}}</script>'))
    m = Media.new url: url
    data = m.as_json
    assert_equal '456567378473870_861850457945558', data['uuid']
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_crowdtangle_data)
    Media.any_instance.unstub(:get_html)
  end

  test "should add text to title when parsing with crowdtangle" do
    Media.any_instance.stubs(:get_crowdtangle_id).returns('100044387231098_287873752702197')
    Media.any_instance.stubs(:render_facebook_embed?).returns(true)
    Media.stubs(:crowdtangle_request).returns({"result"=>{"posts"=>[{"platformId"=>"100044387231098_287873752702197", "date"=>"2021-03-12 16:00:01", "message"=>"Now, that’s a thing of beauty!", "subscriberCount"=>1765162, "media"=>[{"full"=>"https://scontent-sea1-1.xx.fbcdn.net/v/t1.0-9/p720x720/159825434_287873222702250_1913179884649014860_o.jpg?_nc_cat=105&ccb=1-3&_nc_sid=8024bb&_nc_ohc=AVcUyNEYY48AX-slAL_&_nc_ht=scontent-sea1-1.xx&tp=6&oh=d233eeaf648d225af80253841c4c52d1&oe=607295BB"}], "statistics"=>{"actual"=>{"likeCount"=>22415, "shareCount"=>5742, "commentCount"=>2480, "loveCount"=>9991, "wowCount"=>1931, "hahaCount"=>16, "sadCount"=>4, "angryCount"=>0, "thankfulCount"=>0, "careCount"=>382}, "expected"=>{"likeCount"=>4529, "shareCount"=>273, "commentCount"=>206, "loveCount"=>1009, "wowCount"=>19, "hahaCount"=>8, "sadCount"=>2, "angryCount"=>2, "thankfulCount"=>0, "careCount"=>81}}, "account"=>{"id"=>33862, "name"=>"Helloween", "handle"=>"helloweenofficial", "profileImage"=>"https://scontent-sea1-1.xx.fbcdn.net/v/t1.0-1/cp0/p50x50/140782482_257052355784337_1495465363542108697_n.jpg?_nc_cat=1&ccb=1-3&_nc_sid=05dcb7&_nc_ohc=TbrMz5beO2AAX9hex1j&_nc_ht=scontent-sea1-1.xx&tp=27&oh=8a3118e5c28b36277912c6051616bab0&oe=60816335", "subscriberCount"=>1774310, "url"=>"https://www.facebook.com/75052548906", "platform"=>"Facebook", "platformId"=>"100044387231098"}}]}})
    url = 'https://www.facebook.com/helloweenofficial/posts/287873752702197'
    m = Media.new url: url
    data = m.as_json
    assert_equal 'Now, that’s a thing of beauty!', data['title']
    assert_equal 'Now, that’s a thing of beauty!', data['description']
    Media.unstub(:crowdtangle_request)
    Media.any_instance.unstub(:get_crowdtangle_id)
    Media.any_instance.unstub(:render_facebook_embed?)
  end

  test "should get author picture and picture from ld+json" do
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_crowdtangle_data)
    Media.any_instance.stubs(:upload_images)
    Media.any_instance.stubs(:jsonld_tag_content).returns({"@type"=>"VideoObject", "name"=>"sem comentários - Davi Perez Perez", "description"=>"sem comentários", "thumbnailUrl"=>"https://fb.com/thumbnail.jpg", "@id"=>"https://video.mp4", "url"=>"https://video.mp4", "thumbnail"=>{"@type"=>"ImageObject", "contentUrl"=>"https://fb.com/thumbnail.jpg", "width"=>832, "height"=>832}, "publisher"=>{"@type"=>"Organization", "logo"=>{"@type"=>"ImageObject", "url"=>"https://fb.com/author.jpg"}, "name"=>"Davi Perez Perez", "url"=>"https://www.facebook.com/davi.pperez"}, "creator"=>{"@type"=>"Organization", "image"=>"https://fb.com/author.jpg", "name"=>"Davi Perez Perez", "url"=>"https://www.facebook.com/davi.pperez"}, "@context"=>"https://schema.org"})
    url = 'https://www.facebook.com/davi.pperez/posts/3761927773883399'
    m = Media.new url: url
    data = m.as_json
    assert_equal 'https://fb.com/author.jpg', data['author_picture']
    assert_equal 'https://fb.com/thumbnail.jpg', data['picture']
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_crowdtangle_data)
    Media.any_instance.unstub(:upload_images)
    Media.any_instance.unstub(:jsonld_tag_content)
  end

  test "should return nil when FB post id is not present on set url params" do
    Media.any_instance.stubs(:get_crowdtangle_data)
    Media.any_instance.stubs(:parse_from_facebook_html)
    url = 'https://www.facebook.com/media/set?vanity=thelucidpoints'
    media = Media.new(url: url)
    assert_nil media.get_facebook_post_id_from_url
    Media.any_instance.unstub(:get_crowdtangle_data)
    Media.any_instance.unstub(:parse_from_facebook_html)
  end
end
