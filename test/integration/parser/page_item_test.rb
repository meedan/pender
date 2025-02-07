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
    assert_equal 'UOLNoticias', data['author_name']
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
    assert_match(/Hong Kong lawmakers/, data['title'])
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
    assert_match(/Hong Kong lawmakers/, data['title'])
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
    assert_match 'https://www.theguardian.com/profile/zoewilliams', data['author_url']
    assert !data['picture'].blank?
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
