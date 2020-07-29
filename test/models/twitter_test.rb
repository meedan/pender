require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class TwitterTest < ActiveSupport::TestCase
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
    assert_match 'Caio Almeida', data['title']
    assert_match '@caiosba', data['username']
    assert_equal 'twitter', data['provider']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
    assert_kind_of Hash, data['pictures']
  end

  test "should parse tweet" do
    m = create_media url: 'https://twitter.com/caiosba/status/742779467521773568'
    data = m.as_json
    assert_match 'I\'ll be talking in @rubyconfbr this year! More details soon...', data['title']
    assert_match 'Caio Almeida', data['author_name']
    assert_match '@caiosba', data['username']
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

  test "should return author_url for Twitter post" do
    m = create_media url: 'https://twitter.com/TheConfMalmo_AR/status/765474989277638657'
    d = m.as_json
    assert_equal 'https://twitter.com/TheConfMalmo_AR', d['author_url']
  end

  test "should remove line breaks from Twitter item title" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML("<meta name='twitter:title' content='LA Times- USC Dornsife Sunday Poll: <br/> Donald Trump Retains 2 Point <br/> Lead Over Hillary:'>"))
    m = create_media url: 'https://twitter.com/realDonaldTrump/status/785148463868735488'
    d = m.as_json
    assert_match 'LA Times- USC Dornsife Sunday Poll: Donald Trump Retains 2 Point Lead Over Hillary: https://t.co/n05rul4Ycw', d['title']
    Media.any_instance.unstub(:doc)
  end

  test "should parse twitter metatags" do
    doc = nil
    open('test/data/flickr.html') { |f| doc = f.read }
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML(doc))
    m = create_media url: 'https://www.flickr.com/photos/bees/2341623661'
    d = m.as_json
    assert_match 'ZB8T0193', d['title']
    assert_match /Explore .* photos on Flickr!/, d['description']
    assert_equal '', d['published_at']
    assert_match /https:\/\/.*staticflickr.com\/.*3123\/2341623661_7c99f48bbf_b.jpg/, d['picture']
    assert_match /www.flickr.com/, d['author_url']
    Media.any_instance.unstub(:get_html)
  end

  test "should parse twitter metatags 2" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML("<meta name='twitter:title' content='Hong Kong Free Press'><br/><meta name='twitter:creator' content='@krislc'><meta name='twitter:description' content='Chief executive'><meta name='twitter:image' content='http://example.com/image.png'>"))
    m = create_media url: 'https://www.hongkongfp.com/2017/03/08/top-officials-suing-defamation-may-give-perception-bullying-says-chief-exec-candidate-woo/'
    d = m.as_json
    assert_match 'Hong Kong Free Press', d['title']
    assert_match 'http://example.com/image.png', d['picture']
    assert_match 'Chief executive', d['description']
    assert_match '@krislc', d['username']
    assert_match 'https://twitter.com/krislc', d['author_url']
    Media.any_instance.unstub(:doc)
  end

  test "should parse valid link with blank spaces" do
    m = create_media url: ' https://twitter.com/meedan/status/1095034925420560387 '
    d = m.as_json
    assert_equal 'https://twitter.com/meedan/status/1095034925420560387', m.url
    assert_match 'Eleven news organizations and 3 universities are teaming up to fact-check claims related to the May 13, 2019 midterm elections. #TsekPH https://t.co/lXk5ryiQuJ', d['title']
    assert_match 'Eleven news organizations and 3 universities are teaming up to fact-check claims related to the May 13, 2019 midterm elections. #TsekPH', d['description']
    assert_not_nil d['published_at']
    assert_equal '@meedan', d['username']
    assert_equal 'https://twitter.com/meedan', d['author_url']
    assert_nil d['picture']
    assert_not_nil d['author_picture']
  end

  test "should get canonical URL parsed from html tags" do
    media1 = create_media url: 'https://twitter.com/meedan/status/1262644257996898305?ref_src=twsrc%5Etfw'
    media2 = create_media url: 'https://twitter.com/meedan/status/1262644257996898305'
    assert_equal media1.url, media2.url
  end

  test "should parse tweet url with special chars" do
    m = create_media url: 'http://twitter.com/#!/salmaeldaly/status/45532711472992256'
    data = m.as_json
    assert_match 'https://twitter.com/salmaeldaly/status/45532711472992256', m.url
    assert_equal ['twitter', 'item'], [m.provider, m.type]
    assert_match 'وعشان نبقى على بياض أنا مش موافقة على فكرة الاعتصام اللي في التحرير، بس دة حقهم وأنا بدافع عن حقهم الشرعي، بغض النظر عن اختلافي معهم', data['title']
    assert_match data['title'], data['description']
    assert_not_nil data['published_at']
    assert_match '@salmaeldaly', data['username']
    assert_match 'https://twitter.com/salmaeldaly', data['author_url']
    assert_nil data['picture']
    assert_not_nil data['author_picture']
  end

  test "should return Twitter author picture" do
    m = create_media url: 'https://twitter.com/meedan/status/773947372527288320'
    d = m.as_json
    assert_match /^http/, d['author_picture']
  end

  test "should get all information of a truncated tweet" do
    m = create_media url: 'https://twitter.com/bradymakesstuff/status/844240817334247425'
    d = m.as_json
    assert_match 'Anti immigrant graffiti in a portajon on a residential construction site in Mtn Brook, AL. Job has about 50% Latino workers. https://t.co/bS5vI4Jq7I', d['description']
    assert_not_nil d['raw']['api']['entities']['media'][0]['media_url_https']
  end

  test "should store data of post returned by twitter API" do
    m = create_media url: 'https://twitter.com/caiosba/status/742779467521773568'
    data = m.as_json
    assert data['raw']['api'].is_a? Hash
    assert !data['raw']['api'].empty?

    assert_match 'I\'ll be talking in @rubyconfbr this year! More details soon...', data['title']
  end

  test "should store data of profile returned by twitter API" do
    m = create_media url: 'https://twitter.com/RailsGirlsSSA'
    data = m.as_json
    assert data['raw']['api'].is_a? Hash
    assert !data['raw']['api'].empty?
  end

  test "should store oembed data of a twitter post" do
    m = create_media url: 'https://twitter.com/caiosba/status/1205175134400733184'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal "https:\/\/twitter.com", data['raw']['oembed']['provider_url']
    assert_equal "Twitter", data['raw']['oembed']['provider_name']
  end

  test "should store oembed data of a twitter profile" do
    m = create_media url: 'https://twitter.com/TEDTalks'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal "https:\/\/twitter.com", data['raw']['oembed']['provider_url']
    assert_equal "Twitter", data['raw']['oembed']['provider_name']
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
      assert_match '@meedan', data['username']
      assert_match 'meedan', data['author_name']
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

  test "should decode html entities" do
    m = create_media url: 'https://twitter.com/cal_fire/status/919029734847025152'
    data = m.as_json
    assert_no_match /&amp;/, data['title']
  end

  test "add error on media data when cannot find status" do
    Airbrake.stubs(:configured?).returns(true)
    Airbrake.stubs(:notify)
    ['https://twitter.com/caiosba/status/123456789', 'https://twitter.com/cfcffl'].each do |url|
      m = create_media url: url
      data = m.as_json
      assert_match(/Twitter::Error::NotFound/, data['error']['message'])
    end
    Airbrake.unstub(:notify)
    Airbrake.unstub(:configured?)
  end

  test "should have external id for profile" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML("<meta property='og:url' content='https://twitter.com/estadao' data-rdm="">"))
    m = create_media url: 'https://twitter.com/Estadao'
    data = m.as_json
    assert_equal 'estadao', data['external_id']
    Media.any_instance.unstub(:doc)
  end

  test "should have external id for post" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML("<meta property='og:url' content='https://twitter.com/meedan/status/1130872630674972673' data-rdm="">"))
    m = create_media url: 'https://twitter.com/meedan/status/1130872630674972673'
    data = m.as_json
    assert_equal '1130872630674972673', data['external_id']
    Media.any_instance.unstub(:doc)
  end

  test "should leave html blank and add error on media data when private tweet" do
    url = 'https://twitter.com/danieleerze/status/1261075107583127552'
    m = create_media url: url
    data = m.as_json
    assert_equal '', data['html']
    assert_match(/Twitter::Error::Forbidden/, data['error']['message'])
  end

  test "should fill in html when html parsing fails but API works" do
    url = 'https://twitter.com/codinghorror/status/1276934067015974912'
    OpenURI.stubs(:open_uri).raises(OpenURI::HTTPError.new('','429 Too Many Requests'))
    m = create_media url: url
    data = m.as_json
    assert_match /twitter-tweet.*#{url}/, data[:html]
    assert_match(/URL Not Found/, data['error']['message'])
    OpenURI.unstub(:open_uri)
  end

end
