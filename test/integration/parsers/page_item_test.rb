require 'test_helper'

class PageItemIntegrationTest < ActiveSupport::TestCase
  test "should parse a given site" do
    m = create_media url: 'https://noticias.uol.com.br/'
    data = m.as_json
    assert_equal 'item', data['type']
    assert_equal 'page', data['provider']
    assert_match /Acompanhe as últimas notícias do Brasil e do mundo/, data['title']
    assert_not_nil data['description']
    assert_not_nil data['published_at']
    assert_equal '', data['username']
    assert_equal 'https://noticias.uol.com.br', data['author_url']
    assert_equal 'UOLNoticias @UOL', data['author_name']
    assert_not_nil data['picture']
    assert_nil data['error']
  end

  test "should parse arabic url page" do
    url = 'http://www.youm7.com/story/2016/7/6/بالصور-مياه-الشرب-بالإسماعيلية-تواصل-عملها-لحل-مشكلة-طفح-الصرف/2790125'
    id = Media.get_id url
    m = create_media url: url
    data = m.as_json
    assert !data['title'].blank?
    assert_not_nil data['published_at']
    assert_equal '', data['username']
  end

  test "should parse url with arabic or already encoded chars" do
    urls = [
      'https://www.aljazeera.net/news/2023/2/9/الشرطة-السويدية-ترفض-منح-إذن-لحرق',
      'https://www.aljazeera.net/news/2023/2/9/%D8%A7%D9%84%D8%B4%D8%B1%D8%B7%D8%A9-%D8%A7%D9%84%D8%B3%D9%88%D9%8A%D8%AF%D9%8A%D8%A9-%D8%AA%D8%B1%D9%81%D8%B6-%D9%85%D9%86%D8%AD-%D8%A5%D8%B0%D9%86-%D9%84%D8%AD%D8%B1%D9%82'
    ]
    urls.each do |url|
      m = create_media url: url
      data = m.as_json
      assert_equal 'الشرطة السويدية ترفض منح إذن جديد لحرق المصحف الشريف أمام السفارة التركية.. فما السبب؟', data['title']
      assert_equal 'رفضت الشرطة السويدية منح إذن لحرق المصحف الشريف أمام السفارة التركية، قائلة إن ذلك من شأنه “إثارة اضطرابات خطيرة للأمن القومي”.', data['description']
      assert_equal '', data['published_at']
      assert_equal '', data['username']
      assert_match /^https?:\/\/www\.aljazeera\.net$/, data['author_url']
      assert_nil data['error']
      assert_not_nil data['picture']
    end
  end

  test "should store metatags in an Array" do
    m = create_media url: 'https://www.nytimes.com/2017/06/14/us/politics/mueller-trump-special-counsel-investigation.html'
    data = m.as_json
    assert data['raw']['metatags'].is_a? Array
    assert !data['raw']['metatags'].empty?
  end

  test "should handle exception when raises some error when getting oembed data" do
    url = 'https://www.hongkongfp.com/2017/03/01/hearing-begins-in-govt-legal-challenge-against-4-rebel-hong-kong-lawmakers/'
    m = create_media url: url
    OembedItem.any_instance.stubs(:get_oembed_data_from_url).raises(StandardError)
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

  test "should parse pages when the scheme is missing on oembed url" do
    url = 'https://www.hongkongfp.com/2017/03/01/hearing-begins-in-govt-legal-challenge-against-4-rebel-hong-kong-lawmakers/'
    m = create_media url: url
    Parser::PageItem.any_instance.stubs(:oembed_url).returns('//www.hongkongfp.com/wp-json/oembed/1.0/embed?url=https%3A%2F%2Fwww.hongkongfp.com%2F2017%2F03%2F01%2Fhearing-begins-in-govt-legal-challenge-against-4-rebel-hong-kong-lawmakers%2F')
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

  test "should parse url scheme http" do
    url = 'http://www.theatlantic.com/magazine/archive/2016/11/war-goes-viral/501125/'
    m = create_media url: url
    data = m.as_json
    assert_match 'War Goes Viral', data['title']
    assert_match 'How social media is being weaponized across the world', data['description']
    assert !data['published_at'].blank?
    assert_match /Brooking.+Singer/, data['username']
    assert_match /https?:\/\/www.theatlantic.com/, data['author_url']
    assert_not_nil data['picture']
  end

  test "should parse url scheme https" do
    url = 'https://www.theguardian.com/politics/2016/oct/19/larry-sanders-on-brother-bernie-and-why-tony-blair-was-destructive'
    m = create_media url: url
    data = m.as_json
    assert_match 'Larry Sanders on brother Bernie and why Tony Blair was ‘destructive’', data['title']
    assert_match /The Green party candidate, who is fighting the byelection in David Cameron’s old seat/, data['description']
    assert_match /2016-10/, data['published_at']
    assert_match '@zoesqwilliams', data['username']
    assert_match 'https://twitter.com/zoesqwilliams', data['author_url']
    assert !data['picture'].blank?
  end

  test "should parse urls without utf encoding" do
    urls = [
      'https://www.yallakora.com/epl/2545/News/350853/مصدر-ليلا-كورة-ليفربول-حذر-صلاح-وزملاءه-من-جماهير-فيديو-السيارة',
      'https://www.yallakora.com/epl/2545/News/350853/%D9%85%D8%B5%D8%AF%D8%B1-%D9%84%D9%8A%D9%84%D8%A7-%D9%83%D9%88%D8%B1%D8%A9-%D9%84%D9%8A%D9%81%D8%B1%D8%A8%D9%88%D9%84-%D8%AD%D8%B0%D8%B1-%D8%B5%D9%84%D8%A7%D8%AD-%D9%88%D8%B2%D9%85%D9%84%D8%A7%D8%A1%D9%87-%D9%85%D9%86-%D8%AC%D9%85%D8%A7%D9%87%D9%8A%D8%B1-%D9%81%D9%8A%D8%AF%D9%8A%D9%88-%D8%A7%D9%84%D8%B3%D9%8A%D8%A7%D8%B1%D8%A9',
      'https://www.yallakora.com//News/350853/%25D9%2585%25D8%25B5%25D8%25AF%25D8%25B1-%25D9%2584%25D9%258A%25D9%2584%25D8%25A7-%25D9%2583%25D9%2588%25D8%25B1%25D8%25A9-%25D9%2584%25D9%258A%25D9%2581%25D8%25B1%25D8%25A8%25D9%2588%25D9%2584-%25D8%25AD%25D8%25B0%25D8%25B1-%25D8%25B5%25D9%2584%25D8%25A7%25D8%25AD-%25D9%2588%25D8%25B2%25D9%2585%25D9%2584%25D8%25A7%25D8%25A1%25D9%2587-%25D9%2585%25D9%2586-%25D8%25AC%25D9%2585%25D8%25A7%25D9%2587%25D9%258A%25D8%25B1-%25D9%2581%25D9%258A%25D8%25AF%25D9%258A%25D9%2588-%25D8%25A7%25D9%2584%25D8%25B3%25D9%258A%25D8%25A7%25D8%25B1%25D8%25A9-'
    ]
    urls.each do |url|
      m = create_media url: url
      data = m.as_json
      assert data['error'].nil?
    end
  end

  test "should use original url when redirected page requires cookie" do
    RequestHelper.stubs(:get_html).returns(Nokogiri::HTML("<meta property='og:url' content='https://www.tandfonline.com/action/cookieAbsent'><meta name='pbContext' content=';wgroup:string:Publication Websites;website:website:TFOPB;page:string:Cookie Absent'>"))
    url = 'https://doi.org/10.1080/10584609.2019.1619639'
    m = create_media url: url
    data = m.as_json
    assert_equal url, data['url']
    assert_nil data['error']
  end
end
