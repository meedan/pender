require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class FacebookItemTest < ActiveSupport::TestCase
  test "should get canonical URL parsed from facebook html" do
    media1 = create_media url: 'https://www.facebook.com/photo.php?fbid=10155446238011949&set=a.10151842779956949&type=3&theater'
    media2 = create_media url: 'https://www.facebook.com/photo.php?fbid=10155446238011949&set=a.10151842779956949&type=3'
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

  test "should get canonical URL from facebook object 2" do
    media = Media.new(url: 'https://www.facebook.com/permalink.php?story_fbid=10154534111016407&id=54212446406')
    media.as_json({ force: 1 })
    assert_equal 'https://www.facebook.com/54212446406/photos/a.10154534110871407/10154534111016407/?type=3', media.url
  end

  test "should get canonical URL from facebook object 3" do
    expected = 'https://www.facebook.com/54212446406/photos/a.10154534110871407/10154534111016407/?type=3'
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
      url: 'https://www.facebook.com/Classic.mou/photos/a.136991166478555/613639175480416/?type=3',
      title: 'Classic',
      username: 'Classic.mou',
      author_name: 'Classic',
      author_url: 'http://facebook.com/136985363145802',
      author_picture: 'https://graph.facebook.com/136985363145802/picture',
      picture: /613639175480416_2497518582358260577/,
      description: /Classic added a new photo/
    }.with_indifferent_access

    variations = %w(
      https://www.facebook.com/Classic.mou/photos/pcb.613639338813733/613639175480416/?type=3&theater
      https://www.facebook.com/Classic.mou/photos/pcb.613639338813733/613639175480416/
    )
    variations.each do |url|
      media = Media.new(url: url)
      data = media.as_json
      expected.each do |key, value|
        assert_match value, data[key]
      end
    end
  end

  test "should parse Facebook live post from mobile URL" do
    m = create_media url: 'https://m.facebook.com/story.php?story_fbid=10154584426664820&id=355665009819%C2%ACif_t=live_video%C2%ACif_id=1476846578702256&ref=bookmarks'
    data = m.as_json
    assert_match /South China Morning Post/, data['title']
    assert_match /SCMP #FacebookLive amid chaotic scenes in #HongKong Legco/, data['description']
    assert_not_nil data['published_at']
    assert_match 'South China Morning Post', data['author_name']
    assert_match 'http://facebook.com/355665009819', data['author_url']
    assert_match /355665009819/, data['author_picture']
    assert !data['picture'].blank?
  end

  test "should create Facebook post from mobile URL" do
    m = create_media url: 'https://m.facebook.com/KIKOLOUREIROofficial/photos/a.10150618138397252/10152555300292252/?type=3&theater'
    d = m.as_json
    assert_match /Bolívia/, d['text']
    assert_match 'Kiko Loureiro', d['author_name']
    assert_equal 1, d['media_count']
    assert_equal '20/11/2014', Time.parse(d['published_at']).strftime("%d/%m/%Y")
  end

  test "should parse Facebook pure text post url" do
    m = create_media url: 'https://www.facebook.com/dina.samak/posts/10153679232246949?pnref=story.unseen-section'
    d = m.as_json
    assert_match /Dina Samak/, d['title']
    assert_not_nil d['description']
    assert_not_nil d['author_picture']
    assert_not_nil Time.parse(d['published_at'])
  end

  test "should parse Facebook live post" do
    m = create_media url: 'https://www.facebook.com/cbcnews/videos/10154783484119604/'
    data = m.as_json
    assert_equal 'https://www.facebook.com/cbcnews/videos/10154783484119604/', m.url
    assert_match /CBC News/, data['title']
    assert_match /Live now: This is the National for Monday, Oct. 31, 2016./, data['description']
    assert_not_nil data['published_at']
    assert_match 'cbcnews', data['username']
    assert_match 'http://facebook.com/5823419603', data['author_url']
    assert_match /5823419603/, data['author_picture']
    assert_match /^https/, data['picture']
    assert_match /10154783812779604/, data['picture']
  end

  test "should parse Facebook removed live post" do
    m = create_media url: 'https://www.facebook.com/teste637621352/posts/1538843716180215/'
    data = m.as_json
    assert_equal 'https://www.facebook.com/teste637621352/posts/1538843716180215', m.url
    assert_match /Not Identified/, data['title']
    assert_equal '', data['description']
    assert_equal '', data['published_at']
    assert_match 'teste637621352', data['username']
    assert_match 'http://facebook.com/749262715138323', data['author_url']
    assert_match /749262715138323/, data['author_picture']
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
      assert_match /facebook\.com/, m.url
      assert_match /Facebook/, data['title']
      assert_not_nil data['published_at']
    end
  end

  test "should parse Facebook event post" do
    m = create_media url: 'https://www.facebook.com/events/364677040588691/permalink/376287682760960/?ref=1&action_history=null'
    data = m.as_json
    variations = %w(
      https://www.facebook.com/events/364677040588691/permalink/376287682760960?ref=1&action_history=null
      https://www.facebook.com/events/zawya/zawyas-tribute-to-mohamed-khan-%D9%85%D9%88%D8%B9%D8%AF-%D9%85%D8%B9-%D8%AE%D8%A7%D9%86/364677040588691/
      https://web.facebook.com/events/364677040588691/permalink/376287682760960?ref=1&action_history=null&_rdc=1&_rdr
    )
    assert_includes variations, m.url
    assert_not_nil data['published_at']
    assert_match /#{data['user_uuid']}/, data['author_url']
    assert_match /#{data['user_uuid']}/, data['author_picture']
    assert_match /^https:/, data['picture']
    assert_match /Zawya/, data['title']
    assert_match 'Zawya', data['username']
  end

  test "should parse Facebook event url" do
    m = create_media url: 'https://www.facebook.com/events/1090503577698748'
    d = m.as_json
    assert_match /Nancy Ajram/, d['title']
    assert_not_nil d['description']
    assert_match /^http/, d['picture']
    assert_not_nil d['published_at']
    assert_match /1090503577698748/, d['author_picture']
  end

  test "should parse Facebook video url from a page" do
    m = create_media url: 'https://www.facebook.com/144585402276277/videos/1127489833985824'
    d = m.as_json
    assert_match /Trent Aric - Meteorologist/, d['title']
    assert_match /MATTHEW YOU ARE DRUNK...GO HOME!/, d['description']
    assert_equal 'item', d['type']
    assert_not_nil d['picture']
    assert_not_nil Time.parse(d['published_at'])
  end

  test "should parse Facebook video url from a page with another url pattern" do
    m = create_media url: 'https://www.facebook.com/democrats/videos/10154268929856943'
    d = m.as_json
    assert_match /Democratic Party/, d['title']
    assert_match /On National Voter Registration Day/, d['description']
    assert_equal 'item', d['type']
    assert_not_nil d['picture']
    assert_not_nil Time.parse(d['published_at'])
  end

  test "should parse Facebook video url from a profile" do
    m = create_media url: 'https://www.facebook.com/edwinscott143/videos/vb.737361619/10154242961741620/?type=2&theater'
    d = m.as_json
    assert_match /Eddie/, d['title']
    assert_equal 'item', d['type']
    assert_match /^http/, d['picture']
    assert_match /10154242963196620/, d['picture']
    assert_not_nil d['author_picture']
    assert_not_nil Time.parse(d['published_at'])
  end

  test "should parse Facebook video on page album" do
    m = create_media url: 'https://www.facebook.com/scmp/videos/vb.355665009819/10154584426664820/?type=2&theater'
    d = m.as_json
    assert_match /South China Morning Post/, d['title']
    assert_match /SCMP #FacebookLive/, d['description']
    assert_match 'scmp', d['username']
    assert_match /355665009819/, d['author_picture']
    assert_match /10154584445939820/, d['picture']
    assert_match 'http://facebook.com/355665009819', d['author_url']
    assert_not_nil Time.parse(d['published_at'])
    assert_match /South China Morning Post/, d['author_name']
  end

  test "should parse Facebook gif photo url" do
    m = create_media url: 'https://www.facebook.com/quoted.pictures/posts/1095740107184121'
    d = m.as_json
    assert_match /New Quoted Pictures Everyday/, d['title']
    assert_not_nil d['description']
    assert_match /giphy.gif/, d['photos'].first
  end

  test "should parse album post with a permalink" do
    m = create_media url: 'https://www.facebook.com/permalink.php?story_fbid=10154534111016407&id=54212446406'
    d = m.as_json
    assert_match /Mariano Rajoy Brey/, d['title']
    assert_equal 'item', d['type']
    assert_match /54212446406/, d['author_picture']
    assert_match /14543767_10154534111016407_5167486558738906371/, d['picture']
    assert_not_nil Time.parse(d['published_at'])
    assert_match '10154534111016407', d['object_id']
  end

  test "should parse facebook user post" do
    m = create_media url: 'https://www.facebook.com/dina.hawary/posts/10158416884740321'
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal 'facebook', d['provider']
    assert_match /Dina El Hawary/, d['title']
    assert_match /ربنا يزيدهن فوق القوة قوة/, d['description']
    assert_not_nil d['published_at']
    assert_match 'Dina El Hawary', d['author_name']
    assert_match 'dina.hawary', d['username']
    assert_match 'http://facebook.com/813705320', d['author_url']
    assert_match /813705320/, d['author_picture']
    assert_not_nil d['picture']
    assert_nil d['error']
    assert_match 'https://www.facebook.com/dina.hawary/posts/10158416884740321', m.url
  end

  test "should parse facebook url with colon mark" do
    m = create_media url: 'https://www.facebook.com/Classic.mou/posts/666508790193454:0'
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal 'facebook', d['provider']
    assert_match '136985363145802_666508790193454', d['uuid']
    assert_match /Classic/, d['title']
    assert_match /إليزابيث تايلو/, d['description']
    assert_not_nil d['published_at']
    assert_match 'Classic.mou', d['username']
    assert_match 'Classic', d['author_name']
    assert_match 'http://facebook.com/136985363145802', d['author_url']
    assert_match /136985363145802/, d['author_picture']
    assert_match /16473884_666508790193454_8112186335057907723/, d['picture']
    assert_match 'https://www.facebook.com/Classic.mou/photos/a.136991166478555/666508790193454/?type=3', m.url
  end

  test "should parse Facebook post from media set" do
    m = create_media url: 'https://www.facebook.com/media/set/?set=a.10154534110871407.1073742048.54212446406&type=3'
    d = m.as_json
    assert_match '54212446406_10154534110871407', d['uuid']
    assert_match(/En el Museo Serralves de Oporto/, d['text'])
    assert_match '54212446406', d['user_uuid']
    assert_match 'Mariano Rajoy Brey', d['author_name']
    assert d['media_count'] > 20
    assert_match '10154534110871407', d['object_id']
    assert_match 'https://www.facebook.com/media/set?set=a.10154534110871407.1073742048.54212446406&type=3', m.url
  end

  test "should support facebook pattern with pg" do
    m = create_media url: 'https://www.facebook.com/pg/Mariano-Rajoy-Brey-54212446406/photos/?tab=album&album_id=10154534110871407'
    d = m.as_json
    assert_equal 'item', d['type']
    assert_match '54212446406_10154534110871407', d['uuid']
    assert_match(/Militante del Partido Popular/, d['text'])
    assert_match '54212446406', d['user_uuid']
    assert_match 'Mariano Rajoy Brey', d['author_name']
    assert_match '10154534110871407', d['object_id']
    assert_match 'https://www.facebook.com/pages/category/Politician/Mariano-Rajoy-Brey-54212446406/photos/', m.url
  end

  test "should support facebook pattern with album" do
    m = create_media url: 'https://www.facebook.com/album.php?fbid=10154534110871407&id=54212446406&aid=1073742048'
    d = m.as_json
    assert_match '10154534110871407_10154534110871407', d['uuid']
    assert_match(/En el Museo Serralves de Oporto/, d['text'])
    assert_match '10154534110871407', d['user_uuid']
    assert_match 'Mariano Rajoy Brey', d['author_name']
    assert d['media_count'] > 20
    assert_match '10154534110871407', d['object_id']
    assert_match 'https://www.facebook.com/media/set?set=a.10154534110871407', m.url
  end

  test "should get facebook data from original_url when url fails" do
    Media.any_instance.stubs(:url).returns('https://www.facebook.com/Mariano-Rajoy-Brey-54212446406/photos')
    Media.any_instance.stubs(:original_url).returns('https://www.facebook.com/pg/Mariano-Rajoy-Brey-54212446406/photos/?tab=album&album_id=10154534110871407')
    m = create_media url: 'https://www.facebook.com/pg/Mariano-Rajoy-Brey-54212446406/photos'
    d = m.as_json
    assert_match '54212446406_10154534110871407', d['uuid']
    assert_match(/Militante del Partido Popular/, d['text'])
    assert_match '54212446406', d['user_uuid']
    assert_match 'Mariano Rajoy Brey', d['author_name']
    assert_match '10154534110871407', d['object_id']
    Media.any_instance.unstub(:url)
    Media.any_instance.unstub(:original_url)
  end

  test "should parse as html when API token is expired and notify Airbrake" do
    fb_token = CONFIG['facebook_auth_token']
    Airbrake.stubs(:configured?).returns(true)
    Airbrake.stubs(:notify).once
    CONFIG['facebook_auth_token'] = 'EAACMBapoawsBAP8ugWtoTpZBpI68HdM68qgVdLNc8R0F8HMBvTU1mOcZA4R91BsHZAZAvSfTktgBrdjqhYJq2Qet2RMsNZAu12J14NqsP1oyIt74vXlFOBkR7IyjRLLVDysoUploWZC1N76FMPf5Dzvz9Sl0EymSkZD'
    m = create_media url: 'https://www.facebook.com/nostalgia.y/photos/a.508939832569501.1073741829.456182634511888/942167619246718/?type=3&theater'
    data = m.as_json
    assert_match /Nostalgia/, data['title']
    CONFIG['facebook_auth_token'] = fb_token
    data = m.as_json(force: 1)
    assert_match /Nostalgia/, data['title']
    Airbrake.unstub(:configured?)
    Airbrake.unstub(:notify)
  end

  test "should store data of post returned by oembed" do
    m = create_media url: 'https://www.facebook.com/teste637621352/posts/1028416870556238'
    oembed = m.as_json['raw']['oembed']
    assert oembed.is_a? Hash
    assert !oembed.empty?

    assert_nil oembed['title']
    assert_match 'Teste', oembed['author_name']
    assert_match 'https://www.facebook.com/teste637621352/', oembed['author_url']
    assert_equal 'Facebook', oembed['provider_name']
    assert_equal 'https://www.facebook.com', oembed['provider_url']
    assert_equal 552, oembed['width']
    assert oembed['height'].nil?
  end

  test "should store oembed data of a facebook post" do
    m = create_media url: 'https://www.facebook.com/nostalgia.y/photos/a.508939832569501.1073741829.456182634511888/942167619246718/?type=3&theater'
    data = m.as_json

    assert_match 'https://www.facebook.com/nostalgia.y/photos/a.508939832569501/942167619246718/?type=3', m.url
    assert data['raw']['oembed'].is_a? Hash
    assert_equal "https://www.facebook.com", data['raw']['oembed']['provider_url']
    assert_equal "Facebook", data['raw']['oembed']['provider_name']
  end

  test "should store oembed data of a facebook page" do
    m = create_media url: 'https://www.facebook.com/pages/Meedan/105510962816034?fref=ts'
    data = m.as_json
    assert_nil data['raw']['oembed']
    assert_match 'Meedan', data['oembed']['author_name']
    assert_match 'Meedan', data['oembed']['title']
  end

  test "should parse Facebook post from page photo" do
    m = create_media url: 'https://www.facebook.com/quoted.pictures/photos/a.128828073875334.28784.128791873878954/1096134023811396/?type=3&theater'
    d = m.as_json
    assert_match /New Quoted Pictures Everyday/, d['title']
    assert_match /New Quoted Pictures Everyday added a new photo./, d['description']
    assert_match 'quoted.pictures', d['username']
    assert_match 'New Quoted Pictures Everyday', d['author_name']
    assert_not_nil d['author_url']
    assert_not_nil d['picture']
    assert_equal 1, d['media_count']
    assert_equal '08/09/2016', Time.parse(d['published_at']).strftime("%d/%m/%Y")
    assert_match /Pictures/, d['text']
  end

  test "should parse facebook url without identified pattern as item" do
    m = create_media url: 'https://www.facebook.com/Bimbo.Memories/photos/pb.235404669918505.-2207520000.1481570271./1051597428299221/?type=3&theater'
    d = m.as_json
    assert_equal 'item', d['type']
    assert_match /Bimbo Memories/, d['title']
    assert_not_nil d['description']
    assert_not_nil d['published_at']
    assert_match 'Bimbo Memories', d['author_name']
    assert_match 'Bimbo.Memories', d['username']
    assert_match 'http://facebook.com/235404669918505', d['author_url']
    assert_match /235404669918505/, d['author_picture']
    assert_match /15400507_1051597428299221_6315842220063966332/, d['picture']
  end

  test "should parse Facebook photo post within an album url" do
    m = create_media url: 'https://www.facebook.com/ESCAPE.Egypt/photos/ms.c.eJxNk8d1QzEMBDvyQw79N2ZyaeD7osMIwAZKLGTUViod1qU~;DCBNHcpl8gfMKeR8bz2gH6ABlHRuuHYM6AdywPkEsH~;gqAjxqLAKJtQGZFxw7CzIa6zdF8j1EZJjXRgTzAP43XBa4HfFa1REA2nXugScCi3wN7FZpF5BPtaVDEBqwPNR60O9Lsi0nbDrw3KyaPCVZfqAYiWmZO13YwvSbtygCWeKleh9KEVajW8FfZz32qcUrNgA5wfkA4Xfh004x46d9gdckQt2xR74biSOegwIcoB9OW~_oVIxKML0JWYC0XHvDkdZy0oY5bgjvBAPwdBpRuKE7kZDNGtnTLoCObBYqJJ4Ky5FF1kfh75Gnyl~;Qxqsv.bps.a.1204090389632094.1073742218.423930480981426/1204094906298309/?type=3&theater'
    d = m.as_json
    assert_equal '09/2016', Time.parse(d['published_at']).strftime('%m/%Y')
    assert_equal 'item', d['type']
    assert_match /Escape/, d['title']
    assert_match /Escape(\.Egypt)? added a new photo./, d['description']
    assert_match /423930480981426/, d['author_picture']
    assert_equal 1, d['photos'].size
    assert_match /^https:/, d['picture']
    assert_match '1204094906298309', d['object_id']
  end

  test "should parse photo in a photo album" do
    m = create_media url: 'https://www.facebook.com/nostalgia.y/photos/pb.456182634511888.-2207520000.1484079948./928269767303170/?type=3&theater'
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal 'facebook', d['provider']
    assert_match /Nostalgia/, d['title']
    assert_match /مين قالك تسكن فى حاراتنا/, d['description']
    assert_not_nil d['published_at']
    assert_match 'nostalgia.y', d['username']
    assert_match 'Nostalgia', d['author_name']
    assert_match 'http://facebook.com/456182634511888', d['author_url']
    assert_match /456182634511888/, d['author_picture']
    assert_match /15181134_928269767303170_7195169848911975270/, d['picture']
    assert_nil d['error']
  end

  test "should create Facebook post from page photo URL" do
    m = create_media url: 'https://www.facebook.com/teste637621352/photos/a.754851877912740.1073741826.749262715138323/896869113711015/?type=3'
    d = m.as_json
    assert_match '749262715138323_896869113711015', d['uuid']
    assert_match 'This post should be fetched.', d['text']
    assert_match '749262715138323', d['user_uuid']
    assert_match 'Teste', d['author_name']
    assert_match 'teste637621352', d['username']
    assert_equal 1, d['media_count']
    assert_match '896869113711015', d['object_id']
    assert_equal '03/2015', Time.parse(d['published_at']).strftime("%m/%Y")
  end

  test "should create Facebook post from page photos URL" do
    m = create_media url: 'https://www.facebook.com/teste637621352/posts/1028795030518422'
    d = m.as_json
    assert_equal '749262715138323_1028795030518422', d['uuid']
    assert_match 'This is just a test with many photos.', d['text']
    assert_match '749262715138323', d['user_uuid']
    assert_match 'Teste', d['author_name']
    assert_equal 2, d['media_count']
    assert_match '1028795030518422', d['object_id']
    assert_equal '11/2015', Time.parse(d['published_at']).strftime("%m/%Y")
  end

  test "should create Facebook post from user photos URL" do
    m = create_media url: 'https://www.facebook.com/nanabhay/posts/10156130657385246?pnref=story'
    d = m.as_json
    assert_match '735450245_10156130657385246', d['uuid']
    assert_match 'Such a great evening with friends last night. Sultan Sooud Al-Qassemi has an amazing collecting of modern Arab art. It was a visual tour of the history of the region over the last century.', d['text'].strip
    assert_match '735450245', d['user_uuid']
    assert_match 'Mohamed Nanabhay', d['author_name']
    assert_equal 4, d['media_count']
    assert_match '10156130657385246', d['object_id']
    assert_equal '27/10/2015', Time.parse(d['published_at']).strftime("%d/%m/%Y")
  end

  test "should parse Facebook post from user photo URL" do
    m = create_media url: 'https://www.facebook.com/photo.php?fbid=10155150801660195&set=p.10155150801660195&type=1&theater'
    d = m.as_json
    assert_match '10155150801660195_10155150801660195', d['uuid']
    assert_match '10155150801660195', d['user_uuid']
    assert_match 'David Marcus', d['author_name']
    assert_equal 1, d['media_count']
    assert_match '10155150801660195', d['object_id']
    assert_match /David Marcus/, d['title']
    assert_match /10155150801660195/, d['author_picture']
    assert_not_nil d['picture']
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

    m = create_media url: 'https://www.facebook.com/teste637621352/posts/2194142813983632'
    d = m.as_json
    assert_match /^https/, d['author_picture']
    assert_match /^https/, d['picture']
    assert_kind_of Array, d['photos']
    assert_equal 2, d['media_count']
    assert_equal 1, d['photos'].size
  end

  test "should create Facebook post from Arabic user" do
    m = create_media url: 'https://www.facebook.com/ahlam.alialshamsi/posts/108561999277346?pnref=story'
    d = m.as_json
    assert_match '100003706393630_108561999277346', d['uuid']
    assert_match '100003706393630', d['user_uuid']
    assert_match 'Ahlam Ali Al Shāmsi', d['author_name']
    assert_equal 0, d['media_count']
    assert_match '108561999277346', d['object_id']
    assert_match 'أنا مواد رافعة الآن الأموال اللازمة لمشروع مؤسسة خيرية، ودعم المحتاجين في غرب أفريقيا مساعدتي لبناء مكانا أفضل للأطفال في أفريقيا', d['text']
  end

  test "should have a transitive relation between normalized URLs" do
    url = 'https://www.facebook.com/quoted.pictures/photos/a.128828073875334.28784.128791873878954/1096134023811396/?type=3&theater'
    m = create_media url: url
    data = m.as_json
    url = 'https://www.facebook.com/quoted.pictures/photos/a.128828073875334/1096134023811396/?type=3'
    assert_equal url, data['url']

    m = create_media url: url
    data = m.as_json
    assert_equal url, data['url']
  end
  
  test "should return item as oembed" do
    url = 'https://www.facebook.com/pages/Meedan/105510962816034?fref=ts'
    m = create_media url: url
    data = Media.as_oembed(m.as_json, "http://pender.org/medias.html?url=#{url}", 300, 150)
    assert_match 'Meedan', data['title']
    assert_match 'Meedan', data['author_name']
    assert_match 'https://www.facebook.com/pages/Meedan/105510962816034', data['author_url']
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
    assert_match 'Meedan', data['title']
    assert_match 'Meedan', data['author_name']
    assert_match 'https://www.facebook.com/pages/Meedan/105510962816034', data['author_url']
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
    assert_match 'Meedan', data['title']
    assert_match 'Meedan', data['author_name']
    assert_match 'https://www.facebook.com/pages/Meedan/105510962816034', data['author_url']
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
    assert_match 'Teste', data['author_name']
    assert_match 'https://www.facebook.com/teste637621352', data['author_url']
    assert_equal 'Facebook', data['provider_name']
    assert_equal 'https://www.facebook.com', data['provider_url']
    assert_equal 300, data['width']
    assert_equal 150, data['height']

    json = Pender::Store.read(Media.get_id(url), :json)
    assert_equal 552, json[:raw][:oembed][:width]
    assert_nil json[:raw][:oembed][:height]
  end

  test "should not use Facebook embed if is a link to redirect" do
    url = 'https://l.facebook.com/l.php?u=https://hindi.indiatvnews.com/paisa/business-1-07-cr-new-taxpayers-added-dropped-filers-down-at-25-22-lakh-in-fy18-630914&h=AT1WAU-mDHKigOgFNrUsxsS2doGO0_F5W9Yck7oYUx-IsYAHx8JqyHwO02-N0pX8UOlcplZO50px8mkTA1XNyKig8Z2CfX6t3Sh0bHtO9MYPtWqacCm6gOXs5lbC6VGMLjDALNXZ6vg&s=1'

    m = create_media url: url
    data = m.as_json
    assert_match 'Leaving Facebook', data['author_name']
    assert_equal 'flx', data['username']
    assert_equal '', data['html']
  end

  test "should get image from original post if is a shared content" do
    image_name = '32456133_1538581556252460_5832184448275185664'
    original_url = 'https://www.facebook.com/dcc1968/posts/1538584976252118'

    m = create_media url: original_url.to_s
    data = m.as_json
    assert_nil data.dig('original_post')
    assert_match image_name, data[:picture]

    url = 'https://www.facebook.com/danielafeitosa/posts/1862242233833668'
    m = create_media url: url.to_s
    data = m.as_json
    assert_match /facebook.com\/dcc1968/, data.dig('original_post')
    assert_match image_name, data[:picture]
  end

  test "should not get original post if it's already parsing the original post" do
    m = create_media url: 'https://www.facebook.com/groups/1863694297275556/permalink/2193768444268138/'
    data = m.as_json
    original_post = data.dig('original_post')
    assert_not_nil original_post

    original = Media.new url: original_post
    assert_nil original.as_json['original_post']
  end

  test "should have external id for post" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML("<meta property='og:url' content='https://www.facebook.com/ironmaiden/posts/10156071020577051'>"))
    m = create_media url: 'https://www.facebook.com/ironmaiden/posts/10156071020577051'
    data = m.as_json
    assert_equal '10156071020577051', data['external_id']
    Media.any_instance.unstub(:doc)
  end

  test "should parse Facebook category page" do
    m = create_media url: 'https://www.facebook.com/pages/category/Society---Culture-Website/PoporDezamagit/photos/'
    data = m.as_json
    assert_match 'Popor dezamagit on Facebook', data[:title]
  end

  test "should add not found error and return empty html" do
    urls = ['https://www.facebook.com/danielafeitosa/posts/2074906892567200', 'https://www.facebook.com/caiosba/posts/8457689347638947', 'https://www.facebook.com/photo.php?fbid=158203948564609&set=pb.100031250132368.-2207520000..&type=3&theater']
    urls.each do |url|
      m = create_media url: url
      data = m.as_json
      assert_equal '', data[:html]
      assert_equal LapisConstants::ErrorCodes::const_get('NOT_FOUND'), data[:error][:code]
      assert_equal 'URL Not Found', data[:error][:message]
    end
  end

  test "should add login required error and return empty html" do
    m = create_media url: 'https://www.facebook.com/caiosba/posts/2914211445293757'
    data = m.as_json
    assert_equal '', data[:html]
    assert_equal 'Login required to see this profile', data[:error][:message]
    assert_equal LapisConstants::ErrorCodes::const_get('LOGIN_REQUIRED'), data[:error][:code]
  end

  test "should not raise error when canonical URL on meta tags has non-ascii" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML('<meta property="og:title" content="&#x930;&#x93e;&#x91c;&#x928;&#x940;&#x924;&#x93f; no Facebook Watch" /><meta property="og:url" content="https://www.facebook.com/&#x930;&#x93e;&#x91c;&#x928;&#x940;&#x924;&#x93f;-105391010971335/videos/%E0%A4%AF%E0%A5%87-%E0%A4%B5%E0%A4%BF%E0%A4%A1%E0%A5%80%E0%A4%93-%E0%A4%B6%E0%A4%BE%E0%A4%AF%E0%A4%A6-%E0%A4%B0%E0%A4%BE%E0%A4%9C%E0%A4%B8%E0%A5%8D%E0%A4%A5%E0%A4%BE%E0%A4%A8-%E0%A4%95%E0%A5%8D%E0%A4%B7%E0%A5%87%E0%A4%A4%E0%A5%8D%E0%A4%B0-%E0%A4%95%E0%A5%87-%E0%A4%95%E0%A4%BF%E0%A4%B8%E0%A5%80-%E0%A4%97%E0%A4%BE%E0%A4%81%E0%A4%B5-%E0%A4%95%E0%A4%BE-%E0%A4%B9%E0%A5%88-%E0%A4%95%E0%A4%BF%E0%A4%B8%E0%A5%80-%E0%A4%A8%E0%A5%87-%E0%A4%AD%E0%A5%87%E0%A4%9C%E0%A4%BE-%E0%A4%B9%E0%A5%88-%E0%A4%AF%E0%A4%A6%E0%A4%BF-%E0%A4%95%E0%A4%BF%E0%A4%B8%E0%A5%80-%E0%A4%AC%E0%A4%A8%E0%A5%8D%E0%A4%A6%E0%A5%87/258392245354246/" />'))
    assert_nothing_raised do
      m = create_media url: 'https://www.facebook.com/राजनीति-105391010971335/videos/ये-विडीओ-शायद-राजस्थान-क्षेत्र-के-किसी-गाँव-का-है-किसी-ने-भेजा-है-यदि-किसी-बन्दे/258392245354246/'
      data = m.as_json
      assert_match 'राजनीति no Facebook Watch on Facebook', data['title']
      assert_nil data['error']
    end
    Media.any_instance.unstub(:doc)
  end

end
