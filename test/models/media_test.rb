require_relative '../test_helper'
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
      https://meedan.com/
      https://example.com/
      https://ca.ios.ba/?foo=bar
    )
    urls.each do |url|
      media = Media.new(url: url)
      assert_equal url, media.url
    end
  end

  test "should follow redirection of relative paths" do
    assert_nothing_raised do
      m = create_media url: 'http://www.almasryalyoum.com/node/517699'
      data = m.as_json
      assert_match /https:\/\/www.almasryalyoum.com\/editor\/details\/968/, data['url']
    end
  end

  test "should parse URL including cloudflare credentials on header" do
    url = 'https://example.com/'
    parsed_url = Media.parse_url url
    m = Media.new url: url
    header_options_without_cf = Media.send(:html_options, url)
    assert_nil header_options_without_cf['CF-Access-Client-Id']
    assert_nil header_options_without_cf['CF-Access-Client-Secret']
    stub_configs({'hosts' => {"example.com"=>{"cf_credentials"=>"1234:5678"}}})
    header_options_with_cf = Media.send(:html_options, url)
    assert_equal '1234', header_options_with_cf['CF-Access-Client-Id']
    assert_equal '5678', header_options_with_cf['CF-Access-Client-Secret']
    OpenURI.stubs(:open_uri).with(parsed_url, header_options_without_cf).raises(RuntimeError.new('unauthorized'))
    OpenURI.stubs(:open_uri).with(parsed_url, header_options_with_cf)
    assert_equal Nokogiri::HTML::Document, m.send(:get_html, Media.send(:html_options, m.url)).class
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
    m = create_media url: 'https://xkcd.com/1479'
    d = m.as_json
    assert_match /Troubleshooting/, d['title']
    assert_equal '', d['description']
    assert_equal '', d['published_at']
    assert_equal '', d['username']
    assert_equal 'https://xkcd.com', d['author_url']
    assert_match /troubleshooting/, d['picture']
  end

  test "should parse meta tags as fallback 2" do
    m = create_media url: 'http://ca.ios.ba/'
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
    m = create_media url: 'https://meedan.com/en/check/'
    d = m.as_json
    assert_equal 'Product', d['title']
    assert_match(/Engage your audience/, d['description'])
    assert_equal '', d['published_at']
    assert_equal '', d['username']
    assert_equal 'https://meedan.com/check', m.url
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
    assert_match /https:\/\/preview.redd.it\/dj1nk467nfsx.png/, d['picture']
  end

  test "should return success to any valid link 2" do
    m = create_media url: 'http://www.youm7.com/story/2016/7/6/بالصور-مياه-الشرب-بالإسماعيلية-تواصل-عملها-لحل-مشكلة-طفح-الصرف/2790125'
    d = m.as_json
    assert_equal 'بالصور.. مياه الشرب بالإسماعيلية تواصل عملها لحل مشكلة طفح الصرف ببعض الشوارع - اليوم السابع', d['title']
    assert_match /واصلت غرفة عمليات شركة/, d['description']
    assert_not_nil d['published_at']
    assert_equal '', d['username']
    assert_match /https?:\/\/www.youm7.com/, d['author_url']
    assert_equal 'https://img.youm7.com/large/72016619556415g.jpg', d['picture']
  end

  test "should store the picture address" do
    m = create_media url: 'http://xkcd.com/448/'
    d = m.as_json
    assert_match /Good Morning/, d['title']
    assert_equal '', d['description']
    assert_equal '', d['published_at']
    assert_equal '', d['username']
    assert_equal 'https://xkcd.com', d['author_url']
    assert_equal '', d['screenshot']
  end

  test "should get relative canonical URL parsed from html tags" do
    m = create_media url: 'http://meedan.com'
    d = m.as_json
    assert_equal 'https://meedan.com/', m.url
    assert_equal 'Meedan', d['title']
    assert_match /This is Meedan/, d['description']
    assert_equal '', d['published_at']
    assert_equal '', d['username']
    assert_equal 'https://meedan.com', d['author_url']
    assert_match /meedan_logo/, d['picture']
  end

  test "should parse url with arabic or already encoded chars" do
    urls = ['http://www.aljazeera.net/news/arabic/2016/10/19/تحذيرات-أممية-من-احتمال-نزوح-مليون-مدني-من-الموصل', 'http://www.aljazeera.net/news/arabic/2016/10/19/%D8%AA%D8%AD%D8%B0%D9%8A%D8%B1%D8%A7%D8%AA-%D8%A3%D9%85%D9%85%D9%8A%D8%A9-%D9%85%D9%86-%D8%A7%D8%AD%D8%AA%D9%85%D8%A7%D9%84-%D9%86%D8%B2%D9%88%D8%AD-%D9%85%D9%84%D9%8A%D9%88%D9%86-%D9%85%D8%AF%D9%86%D9%8A-%D9%85%D9%86-%D8%A7%D9%84%D9%85%D9%88%D8%B5%D9%84']
    urls.each do |url|
      m = create_media url: url
      d = m.as_json
      assert_equal 'تحذيرات أممية من احتمال نزوح مليون مدني من الموصل', d['title']
      assert_equal 'عبرت الأمم المتحدة عن قلقها البالغ على سلامة 1.5 مليون شخص بالموصل، محذرة من احتمال نزوح مليون منهم، وقالت إن أكثر من 900 نازح فروا إلى سوريا بأول موجة نزوح.', d['description']
      assert_equal '', d['published_at']
      assert_equal '', d['username']
      assert_match /^https?:\/\/www\.aljazeera\.net$/, d['author_url']
      assert_nil d['error']
      assert_match /^https?:\/\/www\.aljazeera\.net/, d['picture']
    end
  end

  test "should parse url scheme http" do
    m = create_media url: 'http://www.theatlantic.com/magazine/archive/2016/11/war-goes-viral/501125/'
    d = m.as_json
    assert_equal 'War Goes Viral', d['title']
    assert_equal 'How social media is being weaponized across the world', d['description']
    assert_equal '', d['published_at']
    assert_equal 'Emerson T. Brooking and P. W. Singer', d['username']
    assert_equal 'https://www.theatlantic.com', d['author_url']
    assert_match /theatlantic/, d['picture']
  end

  test "should parse url scheme https" do
    m = create_media url: 'https://www.theguardian.com/politics/2016/oct/19/larry-sanders-on-brother-bernie-and-why-tony-blair-was-destructive'
    d = m.as_json
    assert_equal 'Larry Sanders on brother Bernie and why Tony Blair was ‘destructive’', d['title']
    assert_match /The Green party candidate, who is fighting the byelection in David Cameron’s old seat/, d['description']
    assert_match /2016-10/, d['published_at']
    assert_equal '@zoesqwilliams', d['username']
    assert_equal 'https://twitter.com/zoesqwilliams', d['author_url']
    assert_match /\/img\/media\/d43d8d320520d7f287adab71fd3a1d337baf7516\/0_945_3850_2310\/master\/3850.jpg/, d['picture']
  end

  test "should return author picture" do
    m = create_media url: 'http://github.com'
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
    m = create_media url: 'https://ca.yahoo.com/'
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
    m = create_media url: 'https://www.yahoo.com/'
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal 'page', d['provider']
    assert_match /Yahoo/, d['title']
    assert_not_nil d['description']
    assert_not_nil d['published_at']
    assert_equal '', d['username']
    assert_not_nil d['author_url']
    assert_match /Yahoo/, d['author_name']
    assert_not_nil d['picture']
    assert_nil d['error']
  end

  test "should return absolute url" do
    m = create_media url: 'https://www.example.com/'
    paths = {
      nil => m.url,
      '' => m.url,
      'http://www.test.bli' => 'http://www.test.bli',
      '//www.test.bli' => 'https://www.test.bli',
      '/example' => 'https://www.example.com/example',
      'www.test.bli' => 'http://www.test.bli'
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
    assert_match /https:\/\/.+AFP/, data['author_url']
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
    assert_match /https:\/\/.+AFP/, data['author_url']
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
    Airbrake.stubs(:configured?).returns(true)

    m.send(:get_html, header_options)

    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_canonical_url)
    Media.any_instance.unstub(:try_https)
    OpenURI.unstub(:open_uri)
    Airbrake.unstub(:configured?)
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
    url = 'https://www.dropbox.com/s/t25htjxk3b3p8oo/A%20Progressive%20Journey%20%2350.mov?dl=0'
    m = create_media url: url
    d = m.as_json
    assert_match /https:\/\/www.dropbox.com\/s\/t25htjxk3b3p8oo\/.*Progressive.*Journey.*2350.mov\?dl=0/, m.url
    assert_equal 'item', d['type']
    assert_equal 'dropbox', d['provider']
    assert_match /A Progressive Journey/, d['title']
    assert_equal 'Shared with Dropbox', d['description']
    assert_not_nil d['published_at']
    assert_equal '', d['username']
    assert_equal '', d['author_url']
    assert_not_nil d['picture']
    assert d['html'].blank?
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
    assert d['html'].blank?
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
    assert d['html'].blank?
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
    assert d['html'].blank?
    assert_nil d['error']
  end

  test "should return empty html on oembed when frame is not allowed" do
    m = create_media url: 'https://ca.ios.ba/files/meedan/frame?2'
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
    m = create_media url: 'https://www.nytimes.com/2017/06/14/us/politics/mueller-trump-special-counsel-investigation.html'
    data = m.as_json
    assert data['raw']['metatags'].is_a? Array
    assert !data['raw']['metatags'].empty?
  end

  test "should not return empty values on metadata keys due to bad html" do
    m = create_media url: 'http://www.politifact.com/truth-o-meter/article/2017/may/09/year-fact-checking-about-james-comey-clinton-email/'
    html = '<meta charset="utf-8">
    <meta http-equiv="x-ua-compatible" content="ie=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta property="og:description" content="James Comey is out as FBI director. "While I greatly appreciate you informing me">'
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML(html))
    tag_description = m.as_json['raw']['metatags'].find { |tag| tag['property'] == 'og:description'}
    assert_equal ['property', 'content'], tag_description.keys
    assert_match /\AJames Comey is out as FBI director.\z/, tag_description['content']
    Media.any_instance.unstub(:doc)
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
    assert_equal 'UOLNoticias @UOL', d['author_name']
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
    assert_equal 'UOLNoticias @UOL', d['author_name']
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

    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
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

  test "should store ClaimReview schema" do
    url = 'http://www.politifact.com/truth-o-meter/statements/2017/aug/17/donald-trump/donald-trump-retells-pants-fire-claim-about-gen-pe'
    m = create_media url: url
    data = m.as_json
    claim_review = data['schema']['ClaimReview'].first
    assert_equal 'ClaimReview', claim_review['@type']
    assert_equal 'http://schema.org', claim_review['@context']
    assert_equal ['@context', '@type', 'author', 'claimReviewed', 'datePublished', 'itemReviewed', 'reviewRating', 'url'], claim_review.keys.sort
  end

  test "should handle schema when type is an array" do
    doc = ''
    open('test/data/page-with-schema.html') { |f| doc = f.read }
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML(doc))

    url = 'https://patents.google.com/patent/US6896907B2/en'
    m = create_media url: url
    data = m.as_json
    article = data['schema']['ScholarlyArticle'].first
    assert_equal 'patent', article['@type']
    assert_equal 'http://schema.org', article['@context']

    Media.any_instance.unstub(:doc)
  end

  test "should return nil on schema key if not found on page" do
    url = 'http://ca.ios.ba/'
    m = create_media url: url
    data = m.as_json
    assert data['schema'].nil?
  end

  test "should store all schemas as array" do
    doc = ''
    open('test/data/page-with-schema.html') { |f| doc = f.read }
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML(doc))

    url = 'https://g1.globo.com/sp/sao-paulo/noticia/pf-indicia-haddad-por-caixa-2-em-campanha-para-a-prefeitura-de-sp.ghtml'
    m = create_media url: url
    data = m.as_json
    assert_equal ['NewsArticle', 'ScholarlyArticle', 'WebPage'], data['schema'].keys.sort
    assert data['schema']['NewsArticle'].is_a? Array
    assert data['schema']['WebPage'].is_a? Array
    assert data['schema']['ScholarlyArticle'].is_a? Array

    Media.any_instance.unstub(:doc)
  end

  test "should store ClaimReview schema after preprocess" do
    url = 'http://www.politifact.com/truth-o-meter/statements/2017/aug/17/donald-trump/donald-trump-retells-pants-fire-claim-about-gen-pe'
    m = create_media url: url
    data = m.as_json
    assert_equal 'ClaimReview', data['schema']['ClaimReview'].first['@type']
    assert_equal 'http://schema.org', data['schema']['ClaimReview'].first['@context']
    assert_equal ['@context', '@type', 'author', 'claimReviewed', 'datePublished', 'itemReviewed', 'reviewRating', 'url'], data['schema']['ClaimReview'].first.keys.sort
  end

  test "should validate author_url when taken from twitter metatags" do
    url = 'http://lnphil.blogspot.com.br/2018/01/villar-at-duterte-nagsanib-pwersa-para.html'
    m = create_media url: url
    data = m.as_json
    assert_equal m.send(:top_url, m.url), data['author_url']
    assert_equal '', data['username']
  end

  test "should handle error when cannot get twitter url" do
    Media.any_instance.stubs(:twitter_client).raises(Twitter::Error::Forbidden)
    m = create_media url: 'http://example.com'
    data = m.as_json
    assert data['error'].nil?
    Media.any_instance.unstub(:twitter_client)
  end

  test "should parse urls without utf encoding" do
    urls = ['https://www.yallakora.com/epl/2545/News/350853/مصدر-ليلا-كورة-ليفربول-حذر-صلاح-وزملاءه-من-جماهير-فيديو-السيارة', 'https://www.yallakora.com/epl/2545/News/350853/%D9%85%D8%B5%D8%AF%D8%B1-%D9%84%D9%8A%D9%84%D8%A7-%D9%83%D9%88%D8%B1%D8%A9-%D9%84%D9%8A%D9%81%D8%B1%D8%A8%D9%88%D9%84-%D8%AD%D8%B0%D8%B1-%D8%B5%D9%84%D8%A7%D8%AD-%D9%88%D8%B2%D9%85%D9%84%D8%A7%D8%A1%D9%87-%D9%85%D9%86-%D8%AC%D9%85%D8%A7%D9%87%D9%8A%D8%B1-%D9%81%D9%8A%D8%AF%D9%8A%D9%88-%D8%A7%D9%84%D8%B3%D9%8A%D8%A7%D8%B1%D8%A9', 'https://www.yallakora.com//News/350853/%25D9%2585%25D8%25B5%25D8%25AF%25D8%25B1-%25D9%2584%25D9%258A%25D9%2584%25D8%25A7-%25D9%2583%25D9%2588%25D8%25B1%25D8%25A9-%25D9%2584%25D9%258A%25D9%2581%25D8%25B1%25D8%25A8%25D9%2588%25D9%2584-%25D8%25AD%25D8%25B0%25D8%25B1-%25D8%25B5%25D9%2584%25D8%25A7%25D8%25AD-%25D9%2588%25D8%25B2%25D9%2585%25D9%2584%25D8%25A7%25D8%25A1%25D9%2587-%25D9%2585%25D9%2586-%25D8%25AC%25D9%2585%25D8%25A7%25D9%2587%25D9%258A%25D8%25B1-%25D9%2581%25D9%258A%25D8%25AF%25D9%258A%25D9%2588-%25D8%25A7%25D9%2584%25D8%25B3%25D9%258A%25D8%25A7%25D8%25B1%25D8%25A9-']
    urls.each do |url|
      m = create_media url: url
      data = m.as_json
      assert data['error'].nil?
    end
  end

  test "should handle errors when call parse" do
    url = 'http://example.com'
    m = create_media url: url
    %w(oembed_item instagram_profile instagram_item page_item dropbox_item facebook_item).each do |parser|
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

  test "should parse page when item on microdata doesn't have type" do
    url = 'https://medium.com/meedan-updates/meedan-at-mediaparty-2019-378f7202d460'
    m = create_media url: url
    Mida::Document.stubs(:new).with(m.doc).returns(OpenStruct.new(items: [OpenStruct.new(id: 'id')]))
    d = m.as_json
    assert_equal 'item', d['type']
    assert_equal 'page', d['provider']
    assert_nil d['error']
    Mida::Document.unstub(:new)
  end

  test "should request URL with User-Agent on header" do
    url = 'https://globalvoices.org/2019/02/16/nigeria-postpones-2019-general-elections-hours-before-polls-open-citing-logistics-and-operations-concerns'
    uri = Media.parse_url url
    Net::HTTP::Head.stubs(:new).with(uri, {'User-Agent' => Media.html_options(uri)['User-Agent'], 'Accept-Language' => 'en-US;q=0.6,en;q=0.4'}).once.returns({})
    Net::HTTP.any_instance.stubs(:request).returns('success')

    assert_equal 'success', Media.request_url(url, 'Head')
    Net::HTTP::Head.unstub(:new)
    Net::HTTP.any_instance.unstub(:request)
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

  test "should rescue error on set_cookies" do
    uri = Media.parse_url('http://ca.ios.ba/')
    PublicSuffix.stubs(:parse).with(uri.host).raises
    assert_equal "", Media.set_cookies(uri)
    PublicSuffix.unstub(:parse)
  end

  test "should return empty html when FB url cannot be embedded" do
    urls = %w(
      https://www.facebook.com/groups/976472102413753/permalink/2013383948722558/
      https://www.facebook.com/caiosba/posts/1913749825339929
      https://www.facebook.com/events/331430157280289
    )
    urls.each do |url|
      m = create_media url: url
      data = m.as_json
      assert_equal 'facebook', data['provider']
      assert_equal '', data['html']
    end
  end

  test "should use proxy for some domains" do
    config = CONFIG['hosts']
    
    CONFIG['hosts'] = { 'time.com' => { 'country' => 'gb' } }
    m = create_media url: 'http://time.com/5058736/climate-change-macron-trump-paris-conference/'
    host, user, pass = Media.get_proxy(m.url)
    assert_match CONFIG['proxy_host'], host
    assert_match "#{CONFIG['proxy_user_prefix']}-cc-GB", user
    assert_equal CONFIG['proxy_pass'], pass

    data = m.as_json
    assert_equal "50 World Leaders Will Discuss Climate Change in Paris. Trump Wasn't Invited", data['title']

    CONFIG['hosts'] = config
  end

  test "should use proxy for some domains 2" do
    config = CONFIG['hosts']
    
    CONFIG['hosts'] = { 'time.com' => { 'country' => 'us' } }
    m = create_media url: 'http://time.com/5058736/climate-change-macron-trump-paris-conference/'
    data = m.as_json
    assert_equal "50 World Leaders Will Discuss Climate Change in Paris. Trump Wasn't Invited", data['title'] 
    
    CONFIG['hosts'] = config
  end

  test "should not replace sharethefacts url if the sharethefacts js is not present" do
    urls = %w(
      https://twitter.com/sharethefact/status/1067835775000215553
      https://twitter.com/factcheckdotorg
    )
    urls.each do |url|
      m = Media.new url: url
      Media.any_instance.stubs(:sharethefacts_replace_element).returns('replaced data')
      assert_nothing_raised do
        assert_no_match /replaced data/, m.send(:get_html, Media.send(:html_options, m.url))
        m.as_json
      end
      Media.any_instance.unstub(:sharethefacts_replace_element)
    end
  end

  test "should match correctly the share the facts url when preprocess html" do
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)

    m = Media.new url: 'http://www.example.com'
    html = '<a href="https://t.co/tLSGfdxUQr" data-expanded-url="http://factcheck.sharethefacts.co/share/0636d2f1-39c5-45b8-b061-db61b4fd0024" ><span class="tco-ellipsis"></span><span class="invisible">http://</span><span class="js-display-url">factcheck.sharethefacts.co/share/0636d2f1</span><span class="invisible">-39c5-45b8-b061-db61b4fd0024</span><span class="tco-ellipsis"><span class="invisible">&nbsp;</span>…</span></a>'
    sharethefacts = 'mock'
    OpenURI.expects(:open_uri).with(URI.parse("https://dhpikd1t89arn.cloudfront.net/html-0636d2f1-39c5-45b8-b061-db61b4fd0024.html")).returns(sharethefacts)
    sharethefacts.stubs(:read).returns('share the facts')
    assert_equal '<div>share the facts</div>', m.find_sharethefacts_links(html)
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_canonical_url)
    Media.any_instance.unstub(:try_https)
    OpenURI.unstub(:open_uri)
  end

  test "should get html again if doc is nil" do
    m = Media.new url: 'http://www.example.com'
    doc = m.send(:get_html, Media.html_options(m.url))
    Media.any_instance.stubs(:get_html).with(Media.send(:html_options, m.url)).returns(nil)
    Media.any_instance.stubs(:get_html).with({allow_redirections: :all}).returns(doc)
    m.as_json
    assert_not_nil m.doc
    Media.any_instance.unstub(:get_html)
  end

  test "should update media cache" do
    url = 'http://www.example.com'
    id = Media.get_id(url)
    m = create_media url: url
    m.as_json

    assert_equal({}, Pender::Store.read(id, :json)['archives'])
    Media.update_cache(url, { archives: { 'archive_org' => 'new-data' } })
    assert_equal({'archive_org' => 'new-data'}, Pender::Store.read(id, :json)['archives'])
  end

  test "should not send errbit error when twitter username is a default" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML("<meta name='twitter:title' content='Page with default Twitter username'><br/><meta name='twitter:creator' content='@username'>"))
    Airbrake.stubs(:configured?).returns(true)
    Airbrake.stubs(:notify).never

    m = create_media url: 'http://www.example.com'
    m.data = Media.minimal_data(m)
    m.get_metatags(m)
    assert_equal 'Page with default Twitter username', m.get_twitter_metadata['title']

    Airbrake.unstub(:configured?)
    Airbrake.unstub(:notify)
    Media.any_instance.unstub(:doc)
  end

  test "should add error on raw oembed and generate the default oembed when can't parse oembed" do
    oembed_response = 'mock'
    oembed_response.stubs(:code).returns('200')
    oembed_response.stubs(:body).returns('<br />\n<b>Warning</b>: {\"version\":\"1.0\"}')
    Media.any_instance.stubs(:oembed_get_data_from_url).returns(oembed_response)
    url = 'https://example.com'
    m = create_media url: url
    data = m.as_json
    assert_match(/unexpected token/, data[:raw][:oembed]['error']['message'])
    assert_match(/Example Domain/, data['oembed']['title'])
    assert_equal 'page', data['oembed']['provider_name']
    Media.any_instance.unstub(:oembed_get_data_from_url)
  end

  test "should handle exception when oembed content is not a valid json" do
    oembed_response = 'response'
    oembed_response.stubs(:code).returns('200')
    oembed_response.stubs(:message).returns('OK')
    oembed_response.stubs(:body).returns('\xEF\xBB\xBF{"version":"1.0","provider_name":"Philippines Lifestyle News"}')
    Media.any_instance.stubs(:oembed_get_data_from_url).returns(oembed_response)
    url = 'https://web.archive.org/web/20190226023026/http://philippineslifestyle.com/flat-earth-theory-support-philippines/'
    m = Media.new url: url
    m.data = Media.minimal_data(m)
    m.data_from_oembed_item
    assert_match(/unexpected token/, m.data[:raw][:oembed]['error']['message'])
    assert_nil m.data['error']
    Media.any_instance.unstub(:oembed_get_data_from_url)
  end

  test "should follow redirections of path relative urls" do
    url = 'https://www.yousign.org/China-Lunatic-punches-dog-to-death-in-front-of-his-daughter-sign-now-t-4358'
    assert_nothing_raised do
      m = create_media url: url
      data = m.as_json
      assert_equal 'https://www.yousign.org/v2_404.php?notfound=/China-Lunatic-punches-dog-to-death-in-front-of-his-daughter-sign-now-t-4358', m.url
    end
  end

  test "should return error if URL is not safe" do
    Media.any_instance.stubs(:unsafe?).returns(true)
    assert_raises Pender::UnsafeUrl do
      m = create_media url: 'http://example.com/paytm.wishesrani.com'
      data = m.as_json
      assert_equal 'UNSAFE', data['error']['code']
    end
    Media.any_instance.unstub(:unsafe?)
  end

  test "should not crash if can't check if URL is not safe" do
    m = create_media url: 'https://meedan.com'
    data = m.as_json
    assert !data['error']
  end

  test "should have external id" do
    m = create_media url: 'http://ca.ios.ba/'
    data = m.as_json
    assert_equal '', data['external_id']
  end

  test "should not reach an infinite loop when parsing Twitter URL" do
    class HttpRedirectionLoop < StandardError
    end
    Airbrake.stubs(:configured?).raises(HttpRedirectionLoop.new('Test'))
    errors = 0
    urls = ['https://twitter.com/com', 'https://twitter.com/hadialabdallah/status/846103320880201729', 'https://twitter.com/syriacivildefe/status/845714970147012608', 'https://twitter.com/SyriaCivilDefe/status/845714970147012608', 'https://twitter.com/Lachybe', 'https://twitter.com/ideas', 'https://twitter.com/psicojen', 'https://twitter.com/account/suspended', 'https://twitter.com/g9wuortn6sve9fn/status/940956917010259970']
    urls.each do |url|
      begin
        Media.new url: url
      rescue HttpRedirectionLoop
        errors += 1
      end
    end
    Airbrake.unstub(:configured?)
    assert_equal 0, errors
  end

  test "should not reach the end of file caused by User-Agent" do
    m = create_media url: 'https://gnbc.news/9669/'
    parsed_url = Media.parse_url m.url
    header_options = Media.send(:html_options, m.url)
    OpenURI.stubs(:open_uri).with(parsed_url, header_options.merge('User-Agent' => 'Mozilla/5.0', 'Accept-Language' => 'en-US;q=0.6,en;q=0.4')).raises(EOFError)
    OpenURI.stubs(:open_uri).with(parsed_url, header_options.merge('User-Agent' => 'Mozilla/5.0 (X11)', 'Accept-Language' => 'en-US;q=0.6,en;q=0.4'))
    assert_nothing_raised do
      m.send(:get_html, header_options)
    end
    OpenURI.unstub(:open_uri)
  end

  test "should parse page when json+ld tag content is an empty array" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML('<script data-rh="true" type="application/ld+json">[]</script>'))
    url = 'https://www.nytimes.com/2019/10/13/world/middleeast/syria-turkey-invasion-isis.html'
    m = create_media url: url
    data = m.as_json
    assert_equal url, data['url']
    assert_nil data['error']
    Media.any_instance.unstub(:doc)
  end

  test "should use original url when redirected page requires cookie" do
    url = 'https://doi.org/10.1080/10584609.2019.1619639'
    m = create_media url: url
    data = m.as_json
    assert_equal url, data['url']
    assert_nil data['error']
  end

  test "should ignore author_name when it is twitter default" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML("<meta content='@username' name='twitter:site'/>"))
    url = 'http://www.dutertenews4network.com/2018/11/leni-nagpunta-sa-london-sinalubong-ng.html'
    m = create_media url: url
    data = m.as_json
    assert_not_equal '@username', data['author_name']
    Media.any_instance.unstub(:doc)
  end

  test "should not raise encoding error when saving data" do
    url = 'https://bastitimes.page/article/raajy-sarakaaren-araajak-tatvon-ke-viruddh-karen-kathoratam-kaarravaee-sonoo-jha/5CvP5F.html'
    data_with_encoding_error = {"published_at"=>"", "description"=>"कर\xE0\xA5", "raw"=>{"metatags"=>[{"content"=>"कर\xE0\xA5"}]}, "schema"=>{"NewsArticle"=>[{"author"=>[{"name"=>"कर\xE0\xA5"}], "headline"=>"कर\xE0\xA5", "publisher"=>{"@type"=>"Organization", "name"=>"कर\xE0\xA5"}}]}, "oembed"=>{"type"=>"rich", "version"=>"1.0", "title"=>"कर\xE0\xA5"}}

    m = create_media url: url
    Media.any_instance.stubs(:data).returns(data_with_encoding_error)
    Media.any_instance.stubs(:parse)

    assert_raises JSON::GeneratorError do
      Pender::Store.write(Media.get_id(m.original_url), :json, data_with_encoding_error)
    end

    assert_nothing_raised do
      data = m.as_json
      assert_equal "कर�", data['description']
      assert_equal "कर�", data['oembed']['title']
      assert_equal "कर�", data['raw']['metatags'].first['content']
      assert_equal "कर�", data['schema']['NewsArticle'].first['headline']
      assert_equal "कर�", data['schema']['NewsArticle'].first['author'].first['name']
      assert_equal "कर�", data['schema']['NewsArticle'].first['publisher']['name']
    end
    Media.any_instance.unstub(:data)
    Media.any_instance.unstub(:parse)
  end

  test "should return empty when get oembed url and doc is nil" do
    m = create_media url: 'https://www.instagram.com/p/B6_wqMHgQ12/6'
    assert_equal '', m.get_oembed_url
  end

  test "should get metrics from Facebook" do
    Media.unstub(:request_metrics_from_facebook)
    app_id = CONFIG['facebook_test_app_id'] || CONFIG['facebook_app_id']
    app_secret = CONFIG['facebook_test_app_secret'] || CONFIG['facebook_app_secret']
    stub_configs({ 'facebook_app_id' => app_id, 'facebook_app_secret' => app_secret }) do
      url = 'https://www.google.com/'
      m = create_media url: url
      m.as_json
      id = Media.get_id(url)
      data = Pender::Store.read(id, :json)
      assert data['metrics']['facebook']['share_count'] > 0
    end
    Media.stubs(:request_metrics_from_facebook).raises(StandardError.new)
    url = 'https://meedan.com'
    m = create_media url: url
    m.as_json
    id = Media.get_id(url)
    data = Pender::Store.read(id, :json)
    assert_equal({}, data['metrics']['facebook'])
  end

  test "should get metrics from Facebook when URL has non-ascii" do
    Media.unstub(:request_metrics_from_facebook)
    assert_nothing_raised do
      response = Media.request_metrics_from_facebook("http://www.facebook.com/people/\u091C\u0941\u0928\u0948\u0926-\u0905\u0939\u092E\u0926/100014835514496")
      assert_kind_of Hash, response
    end
  end

end
