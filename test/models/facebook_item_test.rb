require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class FacebookItemTest < ActiveSupport::TestCase
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

  test "should get canonical URL from facebook object 2" do
    media = Media.new(url: 'https://www.facebook.com/permalink.php?story_fbid=10154534111016407&id=54212446406')
    media.as_json({ force: 1 })
    assert_equal 'https://www.facebook.com/permalink.php?story_fbid=10154534111016407&id=54212446406', media.url
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
    assert_equal 'https://www.facebook.com/scmp/videos/10154584426664820/', m.url
    assert_match /South China Morning Post/, data['title']
    assert_match /SCMP #FacebookLive amid chaotic scenes in #HongKong Legco/, data['description']
    assert_not_nil data['published_at']
    assert_equal 'scmp', data['username']
    assert_equal 'South China Morning Post', data['author_name']
    assert_equal 'http://facebook.com/355665009819', data['author_url']
    assert_equal 'https://graph.facebook.com/355665009819/picture', data['author_picture']
    assert_match /14645700_10154584445939820_3787909207995449344/, data['picture']
  end

  test "should parse Facebook live post" do
    m = create_media url: 'https://www.facebook.com/cbcnews/videos/10154783484119604/'
    data = m.as_json
    assert_equal 'https://www.facebook.com/cbcnews/videos/10154783484119604/', m.url
    assert_match /CBC News/, data['title']
    assert_match /Live now: This is the National for Monday, Oct. 31, 2016./, data['description']
    assert_not_nil data['published_at']
    assert_equal 'cbcnews', data['username']
    assert_equal 'http://facebook.com/5823419603', data['author_url']
    assert_equal 'https://graph.facebook.com/5823419603/picture', data['author_picture']
    assert_match /^https/, data['picture']
    assert_match /14926650_10154783812779604_1342878673929240576/, data['picture']
  end

  test "should parse Facebook removed live post" do
    m = create_media url: 'https://www.facebook.com/teste637621352/posts/1538843716180215/'
    data = m.as_json
    assert_equal 'https://www.facebook.com/teste637621352/posts/1538843716180215', m.url
    assert_match /Not Identified/, data['title']
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
      assert_match /facebook\.com\/watch/, m.url
      assert_match /Facebook Watch/, data['title']
      assert_match /Original shows and popular videos in different categories from producers and creators you love/, data['description']
      assert_not_nil data['published_at']
      assert_equal 'Facebook Watch', data['username']
      assert_equal 'http://facebook.com/', data['author_url']
      assert_equal '', data['author_picture']
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
    assert_match /^https:/, data['picture']
    assert_match /Zawya/, data['title']
    assert_equal 'Zawya', data['username']
  end

  test "should parse Facebook event post 2" do
    m = create_media url: 'https://www.facebook.com/events/364677040588691/permalink/379973812392347/?ref=1&action_history=null'
    data = m.as_json
    variations = %w(
      https://www.facebook.com/events/364677040588691/permalink/379973812392347?ref=1&action_history=null
      https://www.facebook.com/events/zawya/zawyas-tribute-to-mohamed-khan-%D9%85%D9%88%D8%B9%D8%AF-%D9%85%D8%B9-%D8%AE%D8%A7%D9%86/364677040588691/
      https://web.facebook.com/events/364677040588691/permalink/379973812392347?ref=1&action_history=null&_rdc=1&_rdr
    )
    assert_includes variations, m.url
    assert_match /Zawya/, data['title']
    assert_not_nil data['published_at']
    assert_equal 'Zawya', data['username']
    assert_match /#{data['user_uuid']}/, data['author_url']
    assert_match /#{data['user_uuid']}/, data['author_picture']
    assert_not_nil data['picture']
  end

  test "should parse url 4" do
    m = create_media url: 'https://www.facebook.com/ironmaiden/videos/vb.172685102050/10154577999342051/?type=2&theater'
    d = m.as_json
    assert_match /Iron Maiden/, d['title']
    assert_match /Tailgunner! #Lancaster #Aircraft #Plane #WW2 #IronMaiden #TheBookOfSoulsWorldTour #Canada #Toronto #CWHM/, d['description']
    assert_not_nil d['published_at']
    assert_equal 'ironmaiden', d['username']
    assert_equal 'Iron Maiden', d['author_name']
    assert_equal 'http://facebook.com/172685102050', d['author_url']
    assert_equal 'https://graph.facebook.com/172685102050/picture', d['author_picture']
    assert_match /20131236_10154578000322051_2916467421743153152/, d['picture']
  end

  test "should parse facebook url without identified pattern as item" do
    m = create_media url: 'https://www.facebook.com/Bimbo.Memories/photos/pb.235404669918505.-2207520000.1481570271./1051597428299221/?type=3&theater'
    d = m.as_json
    assert_equal 'item', d['type']
    assert_match /Bimbo Memories/, d['title']
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
    assert_match /Classic/, d['title']
    assert_match /سعاد/, d['description']
    assert_not_nil d['published_at']
    assert_equal 'Classic', d['author_name']
    assert_equal 'Classic.mou', d['username']
    assert_equal 'http://facebook.com/136985363145802', d['author_url']
    assert_equal 'https://graph.facebook.com/136985363145802/picture', d['author_picture']
    assert_match /640132509497749_4281523565478374345/, d['picture']
  end

  test "should return Facebook author picture" do
    m = create_media url: 'https://www.facebook.com/ironmaiden/photos/a.406269382050.189128.172685102050/10154015223857051/?type=3&theater'
    d = m.as_json
    assert_match /^http/, d['author_picture']
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
    assert_match /Dina El Hawary/, d['title']
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
    assert_match /Nostalgia/, d['title']
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
    assert_equal 'https://www.facebook.com/nostalgia.y/photos/a.508939832569501/942167619246718/?type=3', m.url
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
    assert_match /Classic/, d['title']
    assert_match /إليزابيث تايلو/, d['description']
    assert_not_nil d['published_at']
    assert_equal 'Classic.mou', d['username']
    assert_equal 'Classic', d['author_name']
    assert_equal 'http://facebook.com/136985363145802', d['author_url']
    assert_equal 'https://graph.facebook.com/136985363145802/picture', d['author_picture']
    assert_match /16473884_666508790193454_8112186335057907723/, d['picture']
    assert_equal 'https://www.facebook.com/Classic.mou/posts/666508790193454:0', m.url
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

  test "should parse Facebook post from media set" do
    m = create_media url: 'https://www.facebook.com/media/set/?set=a.10154534110871407.1073742048.54212446406&type=3'
    d = m.as_json
    assert_equal '54212446406_10154534110871407', d['uuid']
    assert_match(/En el Museo Serralves de Oporto/, d['text'])
    assert_equal '54212446406', d['user_uuid']
    assert_equal 'Mariano Rajoy Brey', d['author_name']
    assert d['media_count'] > 20
    assert_equal '10154534110871407', d['object_id']
    assert_equal 'https://www.facebook.com/media/set?set=a.10154534110871407.1073742048.54212446406&type=3', m.url
  end

  test "should support facebook pattern with pg" do
    m = create_media url: 'https://www.facebook.com/pg/Mariano-Rajoy-Brey-54212446406/photos/?tab=album&album_id=10154534110871407'
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal '54212446406_10154534110871407', d['uuid']
    assert_match(/Militante del Partido Popular/, d['text'])
    assert_equal '54212446406', d['user_uuid']
    assert_equal 'Mariano Rajoy Brey', d['author_name']
    assert_equal '10154534110871407', d['object_id']
    assert_equal 'https://www.facebook.com/pages/category/Politician/Mariano-Rajoy-Brey-54212446406/photos/', m.url
  end

  test "should support facebook pattern with album" do
    m = create_media url: 'https://www.facebook.com/album.php?fbid=10154534110871407&id=54212446406&aid=1073742048'
    d = m.as_json
    assert_equal '10154534110871407_10154534110871407', d['uuid']
    assert_match(/En el Museo Serralves de Oporto/, d['text'])
    assert_equal '10154534110871407', d['user_uuid']
    assert_equal 'Mariano Rajoy Brey', d['author_name']
    assert d['media_count'] > 20
    assert_equal '10154534110871407', d['object_id']
    assert_equal 'https://www.facebook.com/media/set?set=a.10154534110871407', m.url
  end

  test "should get facebook data from original_url when url fails" do
    Media.any_instance.stubs(:url).returns('https://www.facebook.com/Mariano-Rajoy-Brey-54212446406/photos')
    Media.any_instance.stubs(:original_url).returns('https://www.facebook.com/pg/Mariano-Rajoy-Brey-54212446406/photos/?tab=album&album_id=10154534110871407')
    m = create_media url: 'https://www.facebook.com/pg/Mariano-Rajoy-Brey-54212446406/photos'
    d = m.as_json
    assert_equal '54212446406_10154534110871407', d['uuid']
    assert_match(/Militante del Partido Popular/, d['text'])
    assert_equal '54212446406', d['user_uuid']
    assert_equal 'Mariano Rajoy Brey', d['author_name']
    assert_equal '10154534110871407', d['object_id']
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

  test "should store data of a profile returned by facebook API" do
    m = create_media url: 'https://www.facebook.com/profile.php?id=100008161175765&fref=ts'
    data = m.as_json

    assert_equal 'Tico-Santa-Cruz', data[:username]
    assert_equal 'Tico Santa Cruz', data[:title]
    assert !data[:picture].blank?
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

    assert_nil data['raw']['oembed']
    assert_equal 'Tico-Santa-Cruz', data['oembed']['author_name']
    assert_equal 'Tico Santa Cruz', data['oembed']['title']
  end

  test "should store oembed data of a facebook page" do
    m = create_media url: 'https://www.facebook.com/pages/Meedan/105510962816034?fref=ts'
    data = m.as_json
    assert_nil data['raw']['oembed']
    assert_equal 'Meedan', data['oembed']['author_name']
    assert_equal 'Meedan', data['oembed']['title']
  end

  test "should create Facebook post from page post URL without login" do
    m = create_media url: 'https://www.facebook.com/photo.php?fbid=10156907731480246&set=pb.735450245.-2207520000.1502314039.&type=3&theater'
    d = m.as_json
    assert_match /Mohamed Nanabhay/, d['title']
    assert_match /Somewhere off the Aegean Coast..../, d['description']
    assert_equal 'Mohamed Nanabhay', d['author_name']
    assert_equal 'nanabhay', d['username']
    assert_equal 'https://graph.facebook.com/735450245/picture', d['author_picture']
    assert_equal 1, d['media_count']
    assert_not_nil d['picture']
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

  test "should not use Facebook embed if is a link to redirect" do
    url = 'https://l.facebook.com/l.php?u=https://hindi.indiatvnews.com/paisa/business-1-07-cr-new-taxpayers-added-dropped-filers-down-at-25-22-lakh-in-fy18-630914&h=AT1WAU-mDHKigOgFNrUsxsS2doGO0_F5W9Yck7oYUx-IsYAHx8JqyHwO02-N0pX8UOlcplZO50px8mkTA1XNyKig8Z2CfX6t3Sh0bHtO9MYPtWqacCm6gOXs5lbC6VGMLjDALNXZ6vg&s=1'

    m = create_media url: url
    data = m.as_json
    assert_equal 'Leaving Facebook', data['author_name']
    assert_equal 'flx', data['username']
    assert_equal '', data['html']
  end

  test "should get image from original post if is a shared content" do
    image_name = '56652834_855107564821679_1272466202689536000'
    original_url = 'https://www.facebook.com/krishnanand.singh.3323/posts/855107591488343'

    m = create_media url: original_url.to_s
    data = m.as_json
    assert_nil data.dig('original_post')
    assert_match image_name, data[:picture]

    url = 'https://www.facebook.com/amansingh8005/posts/2277227559264498'
    m = create_media url: url.to_s
    data = m.as_json
    assert_equal original_url, data.dig('original_post')
    assert_match image_name, data[:picture]
  end

  test "should get image from original post if is a shared content 2" do
    image_name = '32456133_1538581556252460_5832184448275185664'
    original_url = 'https://www.facebook.com/dcc1968/posts/1538584976252118'

    m = create_media url: original_url.to_s
    data = m.as_json
    assert_nil data.dig('original_post')
    assert_match image_name, data[:picture]

    url = 'https://www.facebook.com/danielafeitosa/posts/1862242233833668'
    m = create_media url: url.to_s
    data = m.as_json
    assert_equal original_url, data.dig('original_post')
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
    m = create_media url: 'https://www.facebook.com/ironmaiden/posts/10156071020577051'
    data = m.as_json
    assert_equal '10156071020577051', data['external_id']
  end

  test "should parse Facebook category page" do
    m = create_media url: 'https://www.facebook.com/pages/category/Society---Culture-Website/PoporDezamagit/photos/'
    data = m.as_json
    assert_equal 'Popor dezamagit on Facebook', data[:title]
  end
end
