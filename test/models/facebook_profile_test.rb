require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class FacebookProfileTest < ActiveSupport::TestCase
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
    assert_equal 300, data['width']
    assert_equal 150, data['height']

    json = Pender::Store.read(Media.get_id(url), :json)
    assert_equal 552, json[:raw][:oembed][:width]
    assert_nil json[:raw][:oembed][:height]
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

  test "should get likes for Facebook profile" do
    m = create_media url: 'https://www.facebook.com/ironmaiden/?fref=ts'
    data = m.as_json
    assert_match /^[0-9]+$/, data['likes'].to_s
  end

  test "should parse Arabic Facebook profile" do
    m = create_media url: 'https://www.facebook.com/%D8%A7%D9%84%D9%85%D8%B1%D9%83%D8%B2-%D8%A7%D9%84%D8%AB%D9%82%D8%A7%D9%81%D9%8A-%D8%A7%D9%84%D9%82%D8%A8%D8%B7%D9%8A-%D8%A7%D9%84%D8%A3%D8%B1%D8%AB%D9%88%D8%B0%D9%83%D8%B3%D9%8A-%D8%A8%D8%A7%D9%84%D9%85%D8%A7%D9%86%D9%8A%D8%A7-179240385797/'
    data = m.as_json
    assert_equal 'المركز الثقافي القبطي الأرثوذكسي بالمانيا', data['title']
  end

  test "should parse Arabic URLs" do
    assert_nothing_raised do
      m = create_media url: 'https://www.facebook.com/إدارة-تموين-أبنوب-217188161807938/'
      data = m.as_json
    end
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
    assert_match /^http/, data['picture']
    assert_not_equal '', data['description'].to_s
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

  test "should create Facebook post from page post URL" do
    m = create_media url: 'https://www.facebook.com/teste637621352/posts/1028416870556238'
    d = m.as_json
    assert_equal '749262715138323_1028416870556238', d['uuid']
    assert_equal "This post is only to test. Esto es una publicación para testar solamente.", d['text']
    assert_equal '749262715138323', d['user_uuid']
    assert_equal 'Teste', d['author_name']
    assert_equal 0, d['media_count']
    assert_equal '1028416870556238', d['object_id']
    assert_equal '11/2015', Time.parse(d['published_at']).strftime("%m/%Y")
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
    assert_equal '03/2015', Time.parse(d['published_at']).strftime("%m/%Y")
  end

  test "should create Facebook post from page photo URL 2" do
    m = create_media url: 'https://www.facebook.com/teste637621352/photos/a.1028424563888802.1073741827.749262715138323/1028424567222135/?type=3&theater'
    d = m.as_json
    assert_equal '749262715138323_1028424567222135', d['uuid']
    assert_equal '749262715138323', d['user_uuid']
    assert_equal 'Teste', d['author_name']
    assert_equal 1, d['media_count']
    assert_equal '1028424567222135', d['object_id']
    assert_equal '11/2015', Time.parse(d['published_at']).strftime("%m/%Y")
    assert_equal 'Teste added a new photo.', d['text']
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
    assert_equal '11/2015', Time.parse(d['published_at']).strftime("%m/%Y")
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
    assert_equal '27/10/2015', Time.parse(d['published_at']).strftime("%d/%m/%Y")
  end

  test "should create Facebook post from user photo URL 2" do
    m = create_media url: 'https://www.facebook.com/photo.php?fbid=1195161923843707&set=a.155912291102014.38637.100000497329098&type=3&theater'
    m = create_media url: 'https://www.facebook.com/photo.php?fbid=981302451896323&set=a.155912291102014.38637.100000497329098&type=3&theater'
    d = m.as_json
    assert_equal '155912291102014_981302451896323', d['uuid']
    assert_equal 'Kiko Loureiro added a new photo.', d['text']
    assert_equal '155912291102014', d['user_uuid']
    assert_equal 'Kiko Loureiro', d['author_name']
    assert_not_nil d['picture']
    assert_equal 1, d['media_count']
    assert_equal '981302451896323', d['object_id']
    assert_equal '21/11/2014', Time.parse(d['published_at']).strftime("%d/%m/%Y")
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
    assert_equal '21/11/2014', Time.parse(d['published_at']).strftime("%d/%m/%Y")
  end

  test "should return author_name and author_url for Facebook post" do
    m = create_media url: 'https://www.facebook.com/photo.php?fbid=1195161923843707&set=a.155912291102014.38637.100000497329098&type=3&theater'
    d = m.as_json
    assert_equal 'http://facebook.com/155912291102014', d['author_url']
    assert_equal 'Kiko Loureiro', d['author_name']
    assert_match /12144884_1195161923843707_2568663037890130414/, d['picture']
  end

  test "should parse Facebook photo post url" do
    m = create_media url: 'https://www.facebook.com/quoted.pictures/photos/a.128828073875334.28784.128791873878954/1096134023811396/?type=3&theater'
    d = m.as_json
    assert_match /New Quoted Pictures Everyday/, d['title']
    assert_match /New Quoted Pictures Everyday added a new photo./, d['description']
    assert_equal 'quoted.pictures', d['username']
    assert_equal 'New Quoted Pictures Everyday', d['author_name']
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
    assert_equal '1204094906298309', d['object_id']
  end

  test "should parse Facebook pure text post url" do
    m = create_media url: 'https://www.facebook.com/dina.samak/posts/10153679232246949?pnref=story.unseen-section'
    d = m.as_json
    assert_match /Dina Samak/, d['title']
    assert_not_nil d['description']
    assert_not_nil d['author_picture']
    assert_not_nil Time.parse(d['published_at'])
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

  test "should parse Facebook video url from a page 2" do
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
    assert_match /Eddie Scott/, d['title']
    assert_equal 'item', d['type']
    assert_match /^http/, d['picture']
    assert_match /14146479_10154242963196620_407850789/, d['picture']
    assert_not_nil d['author_picture']
    assert_not_nil Time.parse(d['published_at'])
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

  test "should parse album post with a permalink" do
    m = create_media url: 'https://www.facebook.com/permalink.php?story_fbid=10154534111016407&id=54212446406'
    d = m.as_json
    assert_match /Mariano Rajoy Brey/, d['title']
    assert_equal 'item', d['type']
    assert_match /54212446406/, d['author_picture']
    assert_match /14543767_10154534111016407_5167486558738906371/, d['picture']
    assert_not_nil Time.parse(d['published_at'])
    assert_equal '10154534111016407', d['object_id']
  end

  test "should parse Facebook gif photo url" do
    m = create_media url: 'https://www.facebook.com/quoted.pictures/posts/1095740107184121'
    d = m.as_json
    assert_match /New Quoted Pictures Everyday/, d['title']
    assert_not_nil d['description']
    assert_match /giphy.gif/, d['photos'].first
  end

  test "should parse Facebook photo on page album" do
    m = create_media url: 'https://www.facebook.com/scmp/videos/vb.355665009819/10154584426664820/?type=2&theater'
    d = m.as_json
    assert_match /South China Morning Post/, d['title']
    assert_match /SCMP #FacebookLive/, d['description']
    assert_equal 'scmp', d['username']
    assert_match /355665009819/, d['author_picture']
    assert_match /14645700_10154584445939820_3787909207995449344/, d['picture']
    assert_equal 'http://facebook.com/355665009819', d['author_url']
    assert_not_nil Time.parse(d['published_at'])
  end

  test "should get Facebook name when metatag is not present" do
    m = create_media url: 'https://www.facebook.com/ironmaiden/'
    doc = ''
    open('test/data/fb-page-without-og-title-metatag.html') { |f| doc = f.read }
    Media.any_instance.stubs(:get_facebook_profile_page).returns(Nokogiri::HTML(doc))

    d = m.as_json
    assert d['error'].nil?
    assert_equal 'Page without `og:title` defined', d['title']
    Media.any_instance.unstub(:get_facebook_profile_page)
  end

  test "should fallback to default Facebook title" do
    m = create_media url: 'https://ca.ios.ba/files/meedan/facebook.html'
    assert_equal 'Facebook', m.get_facebook_name
  end

  test "should have external id for profile" do
    m = create_media url: 'https://www.facebook.com/ironmaiden'
    data = m.as_json
    assert_equal 172685102050, data['external_id']
  end

  test "should parse Facebook person profile" do
    m = create_media url: 'https://facebook.com/caiosba'
    data = m.as_json
    assert_match /Caio/, data[:title]
  end
end
