require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class MediaTest < ActiveSupport::TestCase
  test "should create media" do
    assert_kind_of Media, create_media
  end

  test "should have URL" do
    m = create_media url: 'http://ca.ios.ba/'
    assert_equal 'https://ca.ios.ba/', m.url
  end

  test "should normalize URL" do
    expected = 'https://ca.ios.ba/'
    variations = %w(
      https://ca.ios.ba
      ca.ios.ba
      https://ca.ios.ba:443
      https://ca.ios.ba//
      https://ca.ios.ba/?
      https://ca.ios.ba/#foo
      https://ca.ios.ba/
      https://ca.ios.ba
      https://ca.ios.ba/foo/..
      https://ca.ios.ba/?#
    )
    variations.each do |url|
      media = Media.new(url: url)
      assert_equal expected, media.url
    end

    media = Media.new(url: 'http://ca.ios.ba/a%c3%82/%7Euser?a=b')
    assert_equal 'https://ca.ios.ba/a%C3%82/~user?a=b', media.url

  end

  test "should not normalize URL" do
    urls = %w(
      https://meedan.com/en/
      http://ios.ba/
      https://ca.ios.ba/?foo=bar
    )
    urls.each do |url|
      media = Media.new(url: url)
      assert_equal url, media.url
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
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    m = create_media url: 'https://xkcd.com/1479', request: request
    d = m.as_json
    assert_equal 'xkcd: Troubleshooting', d['title']
    assert_equal '', d['description']
    assert_equal '', d['published_at']
    assert_equal '', d['username']
    assert_equal 'https://xkcd.com', d['author_url']
    assert_equal '', d['picture']
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
    assert_equal 'https://ca.ios.ba', d['author_url']
    assert_equal '', d['picture']
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

  test "should get canonical URL parsed from html tags 3" do
    doc = ''
    open('test/data/page-with-url-on-tag.html') { |f| doc = f.read }
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML(doc))

    media1 = create_media url: 'http://mulher30.com.br/2016/08/bom-dia-2.html'
    media2 = create_media url: 'http://mulher30.com.br/?p=6704&fake=123'
    assert_equal media1.url, media2.url
    Media.any_instance.unstub(:doc)
  end

  test "should return success to any valid link" do
    m = create_media url: 'https://www.reddit.com/r/Art/comments/58a8kp/emotions_language_youngjoo_namgung_ai_livesurface/'
    d = m.as_json
    assert_match /emotion's language, Youngjoo Namgung/, d['title']
    assert_match /.* (points|votes) and .* so far on [Rr]eddit/, d['description']
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
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    m = create_media url: 'http://xkcd.com/448/', request: request
    d = m.as_json
    assert_equal 'xkcd: Good Morning', d['title']
    assert_equal '', d['description']
    assert_equal '', d['published_at']
    assert_equal '', d['username']
    assert_equal 'https://xkcd.com', d['author_url']
    assert_equal '', d['screenshot']
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
    assert_match /2016-10/, d['published_at'].strftime('%Y-%m')
    assert_equal '@zoesqwilliams', d['username']
    assert_equal 'https://twitter.com/zoesqwilliams', d['author_url']
    assert_match /\/img\/media\/d43d8d320520d7f287adab71fd3a1d337baf7516\/0_945_3850_2310\/master\/3850.jpg/, d['picture']
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

  test "should return author picture" do
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    m = create_media url: 'http://github.com', request: request
    d = m.as_json
    assert_match /github-logo.png/, d['author_picture']
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

  test "should handle zlib buffer error when opening a url" do
    m = create_media url: 'https://www.businessdailyafrica.com/'
    parsed_url = Media.parse_url( m.url)
    header_options = Media.send(:html_options, m.url)
    OpenURI.stubs(:open_uri).with(parsed_url, header_options).raises(Zlib::BufError)
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

  test "should redirect to HTTPS if available and not already HTTPS" do
    m = create_media url: 'http://imotorhead.com'
    assert_equal 'https://imotorhead.com/', m.url
  end

  test "should not redirect to HTTPS if available and already HTTPS" do
    m = create_media url: 'https://imotorhead.com'
    assert_equal 'https://imotorhead.com/', m.url
  end

  test "should not redirect to HTTPS if not available" do
    m = create_media url: 'http://www.angra.net'
    assert_equal 'http://angra.net/website', m.url
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

  test "should keep port when building author_url if port is not 443 or 80" do
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

  test "should not return empty values on metadata keys due to bad html" do
    m = create_media url: 'http://www.politifact.com/truth-o-meter/article/2017/may/09/year-fact-checking-about-james-comey-clinton-email/'
    tag_description = m.as_json['raw']['metatags'].find { |tag| tag['property'] == 'og:description'}
    assert_equal ['property', 'content'], tag_description.keys
    assert_match /\AJames Comey is out as FBI director.*last July.\z/, tag_description['content']
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

  test "should skip screenshots" do
    config = CONFIG['archiver_skip_hosts']

    CONFIG['archiver_skip_hosts'] = ''

    a = create_api_key application_settings: { 'webhook_url': 'https://webhook.site/19cfeb40-3d06-41b8-8378-152fe12e29a8', 'webhook_token': 'test' }
    url = 'https://checkmedia.org/caio-screenshots/project/1121/media/8390'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    data = m.as_json

    CONFIG['archiver_skip_hosts'] = 'checkmedia.org'

    url = 'https://checkmedia.org/caio-screenshots/project/1121/media/8390?hide_tasks=1'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    data = m.as_json

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

  test "should handle error when cannot get twitter url" do
    request = 'http://localhost'
    request.expects(:base_url).returns('http://localhost')
    Media.any_instance.stubs(:twitter_client).raises(Twitter::Error::Forbidden)
    url = 'http://www.yallakora.com/epl/2545/News/350853/%D9%85%D8%B5%D8%AF%D8%B1-%D9%84%D9%8A%D9%84%D8%A7-%D9%83%D9%88%D8%B1%D8%A9-%D9%84%D9%8A%D9%81%D8%B1%D8%A8%D9%88%D9%84-%D8%AD%D8%B0%D8%B1-%D8%B5%D9%84%D8%A7%D8%AD-%D9%88%D8%B2%D9%85%D9%84%D8%A7%D8%A1%D9%87-%D9%85%D9%86-%D8%AC%D9%85%D8%A7%D9%87%D9%8A%D8%B1-%D9%81%D9%8A%D8%AF%D9%8A%D9%88-%D8%A7%D9%84%D8%B3%D9%8A%D8%A7%D8%B1%D8%A9'
    m = create_media url: url, request: request
    data = m.as_json
    assert data['error'].nil?
    Media.any_instance.unstub(:twitter_client)
  end

  test "should handle errors when call parse" do
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

  test "should convert published_time to time without error" do
    url = 'https://www.pagina12.com.ar/136611-tecnologias-de-la-desinformacion'
    m = Media.new(url: url)
    data = m.as_json
    assert_nothing_raised do
      data['published_at'].to_time
    end
  end

  test "should add cookie from cookie.txt on header if domain matches" do
    url_no_cookie = 'http://ca.ios.ba/'
    assert_equal "", Media.send(:html_options, url_no_cookie)['Cookie']
    url_with_cookie = 'https://www.washingtonpost.com/politics/winter-is-coming-allies-fear-trump-isnt-prepared-for-gathering-legal-storm/2018/08/29/b07fc0a6-aba0-11e8-b1da-ff7faa680710_story.html'
    assert_match "wp_devicetype=0", Media.send(:html_options, url_with_cookie)['Cookie']
  end
end
