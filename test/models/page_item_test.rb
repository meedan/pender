require 'test_helper'

# class PageItemIntegrationTest < ActiveSupport::TestCase
#   test "should parse ca yahoo site" do
#     m = create_media url: 'https://ca.yahoo.com/'
#     data = m.as_json
#     assert_equal 'item', data['type']
#     assert_equal 'page', data['provider']
#     assert_match 'Yahoo', data['title']
#     assert_not_nil data['description']
#     assert_not_nil data['published_at']
#     assert_equal '', data['username']
#     assert_match 'https://ca.yahoo.com', data['author_url']
#     assert_match 'Yahoo', data['author_name']
#     assert_not_nil data['picture']
#     assert_nil data['error']
#   end

#   test "should parse us yahoo site" do
#     m = create_media url: 'https://www.yahoo.com/'
#     data = m.as_json
#     assert_equal 'item', data['type']
#     assert_equal 'page', data['provider']
#     assert_match /Yahoo/, data['title']
#     assert_not_nil data['description']
#     assert_not_nil data['published_at']
#     assert_equal '', data['username']
#     assert_not_nil data['author_url']
#     assert_match /Yahoo/, data['author_name']
#     assert_not_nil data['picture']
#     assert_nil data['error']
#   end

#   test "should get author_name from site" do
#     m = create_media url: 'https://noticias.uol.com.br/'
#     data = m.as_json
#     assert_equal 'item', data['type']
#     assert_equal 'page', data['provider']
#     assert_match /Acompanhe as últimas notícias do Brasil e do mundo/, data['title']
#     assert_not_nil data['description']
#     assert_not_nil data['published_at']
#     assert_equal '', data['username']
#     assert_equal 'https://noticias.uol.com.br', data['author_url']
#     assert_equal 'UOLNoticias @UOL', data['author_name']
#     assert_not_nil data['picture']
#     assert_nil data['error']
#   end

#   test "should parse url with redirection https -> http" do
#     m = create_media url: 'https://noticias.uol.com.br/cotidiano/ultimas-noticias/2017/07/18/nove-anos-apos-ser-condenado-por-moro-beira-mar-repete-trafico-em-presidio-federal.htm'
#     data = m.as_json
#     assert_equal 'item', data['type']
#     assert_equal 'page', data['provider']
#     assert_match /Nove anos após ser condenado/, data['title']
#     assert_not_nil data['description']
#     assert_not_nil data['published_at']
#     assert_equal '', data['username']
#     assert_equal 'https://noticias.uol.com.br', data['author_url']
#     assert_equal 'UOLNoticias @UOL', data['author_name']
#     assert_not_nil data['picture']
#     assert_nil data['error']
#   end

#   test "should parse page when item on microdata doesn't have type" do
#     url = 'https://medium.com/meedan-updates/meedan-at-mediaparty-2019-378f7202d460'
#     m = create_media url: url
#     Mida::Document.stubs(:new).with(m.doc).returns(OpenStruct.new(items: [OpenStruct.new(id: 'id')]))
#     data = m.as_json
#     assert_equal 'item', data['type']
#     assert_equal 'page', data['provider']
#     assert_nil data['error']
#     Mida::Document.unstub(:new)
#   end

#   test "should not crash if can't check if URL is not safe" do
#     m = create_media url: 'https://meedan.com'
#     data = m.as_json
#     assert !data['error']
#   end

#   test "should get html again if doc is nil" do
#     m = Media.new url: 'http://www.example.com'
#     doc = m.send(:get_html, Media.html_options(m.url))
#     Media.any_instance.stubs(:get_html).with(Media.send(:html_options, m.url)).returns(nil)
#     Media.any_instance.stubs(:get_html).with({allow_redirections: :all}).returns(doc)
#     m.as_json
#     assert_not_nil m.doc
#     Media.any_instance.unstub(:get_html)
#   end

#   test "should not overwrite metatags with nil" do
#     m = create_media url: 'http://meedan.com'
#     m.expects(:get_opengraph_metadata).returns({author_url: nil})
#     m.expects(:get_twitter_metadata).returns({author_url: nil})
#     m.expects(:get_oembed_metadata).returns({})
#     m.expects(:get_basic_metadata).returns({description: "", title: "Meedan Checkdesk", username: "Tom", published_at: "", author_url: "https://meedan.checkdesk.org", picture: 'meedan.png'})
#     data = m.as_json
#     assert_match 'Meedan Checkdesk', data['title']
#     assert_match 'Tom', data['username']
#     assert_not_nil data['description']
#     assert_not_nil data['picture']
#     assert_not_nil data['published_at']
#     assert_match 'https://meedan.checkdesk.org', data['author_url']
#   end

#   test "should parse opengraph metatags" do
#     m = create_media url: 'https://hacktoberfest.digitalocean.com/'
#     m.as_json
#     data = m.get_opengraph_metadata
#     assert_match "Hacktoberfest '21", data['title']
#     assert_match(/Open source/, data['description'])
#     assert_match 'Hacktoberfest presented by DigitalOcean', data['author_name']
#     assert_not_nil data['picture']
#   end

#   test "should parse meta tags as fallback" do
#     m = create_media url: 'http://ca.ios.ba/'
#     assert_match 'https://ca.ios.ba/', m.url
#     data = m.as_json
#     assert_match 'CaioSBA', data['title']
#     assert_match 'Personal website of Caio Sacramento de Britto Almeida', data['description']
#     assert_equal '', data['published_at']
#     assert_equal '', data['username']
#     assert_match 'https://ca.ios.ba', data['author_url']
#     assert_equal '', data['picture']
#   end

  # test "should store metatags in an Array" do
  #   m = create_media url: 'https://www.nytimes.com/2017/06/14/us/politics/mueller-trump-special-counsel-investigation.html'
  #   data = m.as_json
  #   assert data['raw']['metatags'].is_a? Array
  #   assert !data['raw']['metatags'].empty?
  # end

  # test "should parse pages when the scheme is missing on oembed url" do
  #   url = 'https://www.hongkongfp.com/2017/03/01/hearing-begins-in-govt-legal-challenge-against-4-rebel-hong-kong-lawmakers/'
  #   m = create_media url: url
  #   Parser::Base.any_instance.stubs(:oembed_url).returns('//www.hongkongfp.com/wp-json/oembed/1.0/embed?url=https%3A%2F%2Fwww.hongkongfp.com%2F2017%2F03%2F01%2Fhearing-begins-in-govt-legal-challenge-against-4-rebel-hong-kong-lawmakers%2F')
  #   data = m.as_json
  #   assert_equal 'item', data['type']
  #   assert_equal 'page', data['provider']
  #   assert_match(/Hong Kong Free Press/, data['title'])
  #   assert_match(/Hong Kong/, data['description'])
  #   assert_not_nil data['published_at']
  #   assert_match /https:\/\/.+AFP/, data['author_url']
  #   assert_not_nil data['picture']
  #   assert_nil data['error']
  # end

  # test "should handle exception when raises some error when get oembed data" do
  #   url = 'https://www.hongkongfp.com/2017/03/01/hearing-begins-in-govt-legal-challenge-against-4-rebel-hong-kong-lawmakers/'
  #   m = create_media url: url
  #   Parser::Base.any_instance.stubs(:oembed_url).raises(StandardError)
  #   data = m.as_json
  #   assert_equal 'item', data['type']
  #   assert_equal 'page', data['provider']
  #   assert_match(/Hong Kong Free Press/, data['title'])
  #   assert_match(/Hong Kong/, data['description'])
  #   assert_not_nil data['published_at']
  #   assert_match /https:\/\/.+AFP/, data['author_url']
  #   assert_not_nil data['picture']
  #   assert_match(/StandardError/, data['error']['message'])
  # end
# end

class PageItemUnitTest < ActiveSupport::TestCase
  def setup
    isolated_setup
    WebMock.stub_request(:post, /safebrowsing.googleapis.com/).to_return(status: 200, body: { matches: [] }.to_json )
  end

  def teardown
    isolated_teardown
  end

  def empty_doc
    Nokogiri::HTML('')
  end

  def oembed_doc
    Nokogiri::HTML(<<~HTML)
      <link rel="alternate" type="application/json+oembed" href="https://example.com/oembed">
    HTML
  end

  def throwaway_url
    'https://example.com/throwaway'
  end

  test "returns provider and type" do
    assert_equal Parser::PageItem.type, 'page_item'
  end

  test "matches everything, as a fallback" do
    assert Parser::PageItem.match?('https://example.com').is_a?(Parser::PageItem)
  end

  test "re-fetches HTML and sets metatags, following all redirects, if doc is empty" do
    url = 'https://example.com'
    RequestHelper.stubs(:get_html).with(url, kind_of(Method), {allow_redirections: :all}).returns(Nokogiri::HTML('<meta name="description" content="hello" />'))

    data = Parser::PageItem.new('https://example.com').parse_data(nil, 'https://example.com/original')
    assert_equal data.dig('raw', 'metatags').size, 1
    assert_equal data.dig('raw', 'metatags')[0]['content'], 'hello'
  end

  test "sets and reports error if HTML cannot be retrieved on second try" do
    RequestHelper.stubs(:get_html).returns(nil)

    data = {}
    airbrake_call_count = 0
    arguments_checker = Proc.new do |e|
      airbrake_call_count += 1
      assert_equal Parser::PageItem::HtmlFetchingError, e.class
    end

    PenderAirbrake.stub(:notify, arguments_checker) do
      data = Parser::PageItem.new('https://example.com').parse_data(nil, throwaway_url)
      assert_equal 1, airbrake_call_count
    end

    assert_match /HtmlFetchingError/, data[:error][:message]
  end

  # Need to address ordering of behavior
  test "sets title from metatags when present" do
    doc = Nokogiri::HTML('<meta property="title" content="this is a title" />')
    data = Parser::PageItem.new('https://example.com').parse_data(doc, throwaway_url)

    assert_equal 'this is a title', data['title']
  end

  test "sets title HTML element when present" do
    doc = Nokogiri::HTML('<title>this is a title</title>')
    data = Parser::PageItem.new('https://example.com').parse_data(doc, throwaway_url)

    assert_equal 'this is a title', data['title']
  end

  test "sets description from metatags when present" do
    doc = Nokogiri::HTML('<meta property="description" content="this is a description" />')
    data = Parser::PageItem.new('https://example.com').parse_data(doc, throwaway_url)

    assert_equal 'this is a description', data['description']
  end

  test "sets description HTML element when present" do
    doc = Nokogiri::HTML('<description>this is a description</description>')
    data = Parser::PageItem.new('https://example.com').parse_data(doc, throwaway_url)

    assert_equal 'this is a description', data['description']
  end

  test "requests oembed data from URL in HTMl and assigns returned data" do
    fake_oembed_item = Proc.new do |url|
      assert_equal 'https://example.com/oembed', url

      OpenStruct.new(get_data: {
        author_name: 'Piglet McDog',
        summary: "She's a great pup",
        title: "Piglet's house",
        thumbnail_url: 'https://example.com/pig-small.jpg',
        html: '<div id="dog"></div>',
        author_url: 'https://example.com/pig-small.jpg',
      })
    end

    data = {}
    OembedItem.stub(:new, fake_oembed_item) do
      data = Parser::PageItem.new('https://example.com').parse_data(oembed_doc, throwaway_url)
    end

    assert !data['raw']['oembed'].empty?
    assert_nil data['raw']['oembed']['error']

    assert_nil data['published_at']
    assert_equal data['username'], 'Piglet McDog'
    assert_equal data['description'], "She's a great pup"
    assert_equal data['title'], "Piglet's house"
    assert_equal data['picture'], "https://example.com/pig-small.jpg"
    assert_equal data['html'], '<div id="dog"></div>'
    assert_equal data['author_url'], 'https://example.com/pig-small.jpg'
  end

  test "falls back to using title for description from oembed data when summary not available" do
    OembedItem.any_instance.stubs(:get_data).returns(
      {
        title: "Piglet's house",
      }
    )
    data = Parser::PageItem.new('https://example.com').parse_data(oembed_doc, throwaway_url)

    assert_equal "Piglet's house", data['description']
  end

  test "does not set oembed data if there is an issue with returned oembed data" do
    OembedItem.any_instance.stubs(:get_data).returns( 
      {
        error: { some: 'error' },
        summary: "Piglet's house",
      }
    )
    data = Parser::PageItem.new('https://example.com').parse_data(oembed_doc, throwaway_url)

    assert_nil data['title']
  end

  test "sets opengraph metadata" do
    doc = Nokogiri::HTML(<<~HTML)
      <meta property="og:title" content="Piglet's page"/>
      <meta property="og:image" content="http://example.com/image"/>
      <meta property="og:description" content="A place for dogs, surprisingly"/>
      <meta property="article:author" content="Piglet McDog"/>
      <meta property="og:site_name" content="Piglet McDog's Blog"/>
    HTML
    data = Parser::PageItem.new('https://example.com').parse_data(doc, throwaway_url)

    assert_equal "Piglet's page", data['title']
    assert_equal 'http://example.com/image', data['picture']
    assert_equal 'A place for dogs, surprisingly', data['description']
    assert_equal 'Piglet McDog', data['username']
    assert_equal "Piglet McDog's Blog", data['author_name']
  end

  test "converts opengraph published_at time to valid time object" do
    doc = Nokogiri::HTML(<<~HTML)
      <meta property="article:published_time" content="1534810765"/>
    HTML
    data = Parser::PageItem.new('https://example.com').parse_data(doc, throwaway_url)
    assert_nothing_raised do
      data['published_at'].to_time
    end
  end

  test "sets author_url to opengraph article:author if a URL pattern rather than username" do
    doc = Nokogiri::HTML(<<~HTML)
      <meta property="article:author" content="https://example.com/author-url" />
    HTML
    data = Parser::PageItem.new('https://example.com').parse_data(doc, throwaway_url)

    assert_equal 'https://example.com/author-url', data['author_url']
    assert_nil data['username']
  end

  test "sets twitter metdata" do
    doc = Nokogiri::HTML(<<~HTML)
      <meta property="twitter:title" content="Piglet's page"/>
      <meta property="twitter:image" content="http://example.com/image"/>
      <meta property="twitter:description" content="A place for dogs, surprisingly"/>
      <meta property="twitter:creator" content="@piglet"/>
      <meta property="twitter:site" content="Piglet McDog's Blog"/>
    HTML
    data = Parser::PageItem.new('https://example.com').parse_data(doc, throwaway_url)

    assert_equal "Piglet's page", data['title']
    assert_equal 'http://example.com/image', data['picture']
    assert_equal 'A place for dogs, surprisingly', data['description']
    assert_equal '@piglet', data['username']
    assert_equal "Piglet McDog's Blog", data['author_name']
  end
  
  # Note: this is existing behavior, but could see it having unintended results
  test "adds http to beginning of picture URL when needed" do
    doc = Nokogiri::HTML('<meta property="og:image" content="piglet.com/image.png" />')
    data = Parser::PageItem.new('https://example.com').parse_data(doc, throwaway_url)
    assert_equal 'http://piglet.com/image.png', data['picture']

    doc = Nokogiri::HTML('<meta property="og:image" content="http://piglet.com/image.png" />')
    data = Parser::PageItem.new('https://example.com').parse_data(doc, throwaway_url)
    assert_equal 'http://piglet.com/image.png', data['picture']

    doc = Nokogiri::HTML('<meta property="og:image" content="https://piglet.com/image.png" />')
    data = Parser::PageItem.new('https://example.com').parse_data(doc, throwaway_url)
    assert_equal 'https://piglet.com/image.png', data['picture']
  end

  test "sets author name as author_name, username, and then title" do
    doc = Nokogiri::HTML(<<~HTML)
      <meta property="twitter:site" content="Piglet McDog"/>'
      <meta property="twitter:creator" content="@piglet"/>'
      <meta property="twitter:title" content="Piglet McDog's Blog"/>'
    HTML
    data = Parser::PageItem.new('https://example.com').parse_data(doc, throwaway_url)
    assert_equal "Piglet McDog", data['author_name']

    doc = Nokogiri::HTML(<<~HTML)
      <meta property="twitter:creator" content="@piglet"/>'
      <meta property="twitter:title" content="Piglet McDog's Blog"/>'
    HTML
    data = Parser::PageItem.new('https://example.com').parse_data(doc, throwaway_url)
    assert_equal "@piglet", data['author_name']

    doc = Nokogiri::HTML(<<~HTML)
      <meta property="twitter:title" content="Piglet McDog's Blog"/>'
    HTML
    data = Parser::PageItem.new('https://example.com').parse_data(doc, throwaway_url)
    assert_equal "Piglet McDog's Blog", data['author_name']
  end

  test "sets author_picture to picture" do
    doc = Nokogiri::HTML('<meta property="twitter:image" content="http://example.com/image"/>')
    data = Parser::PageItem.new('https://example.com').parse_data(doc, throwaway_url)
    assert_equal 'http://example.com/image', data['author_picture']
  end

  test "reassigns url to original URL if cookies are required and not present" do
    doc = Nokogiri::HTML('<meta property="pbContext" content="Cookie Absent"/>')
    parser = Parser::PageItem.new('https://example.com')
    data = parser.parse_data(doc, 'https://example.com/original')

    assert_equal 'https://example.com/original', parser.url
  end

  test "raises error if url is deemed unsafe by google" do
    WebMock.stub_request(:post, /safebrowsing.googleapis.com/).
      with(body: /example.com\/unsafeurl/).
      to_return(status: 200, body: { matches: ['fake match'] }.to_json )

    # url
    assert_raises Pender::UnsafeUrl do
      Parser::PageItem.new('https://example.com/unsafeurl').parse_data(empty_doc, throwaway_url)
    end
  end

  test "raises error if author_url, author_picture, or picture are deemed unsafe by google" do
    WebMock.stub_request(:post, /safebrowsing.googleapis.com/).
      with(body: /example.com\/safeurl/).
      to_return(status: 200, body: { matches: [] }.to_json )

    WebMock.stub_request(:post, /safebrowsing.googleapis.com/).
      with(body: /example.com\/unsafeurl/).
      to_return(status: 200, body: { matches: ['fake match'] }.to_json )

    # author_url
    doc = Nokogiri::HTML(<<~HTML)
      <meta property="article:author" content="https://example.com/unsafeurl" />
    HTML
    assert_raises Pender::UnsafeUrl do
      Parser::PageItem.new('https://example.com/safeurl').parse_data(doc, throwaway_url)
    end

    # author_picture
    doc = Nokogiri::HTML(<<~HTML)
      <meta property="article:author" content="https://example.com/unsafeurl" />
    HTML
    assert_raises Pender::UnsafeUrl do
      Parser::PageItem.new('https://example.com/safeurl').parse_data(doc, throwaway_url)
    end

    # picture
    doc = Nokogiri::HTML(<<~HTML)
      <meta property="article:author" content="https://example.com/unsafeurl" />
    HTML
    assert_raises Pender::UnsafeUrl do
      Parser::PageItem.new('https://example.com/safeurl').parse_data(doc, throwaway_url)
    end
  end

  test "sets author URL to the top-level URL" do
    data = Parser::PageItem.new('https://www.nytimes.com/live/2022/09/09/world/queen-elizabeth-king-charles').parse_data(empty_doc, throwaway_url)

    assert_equal 'https://www.nytimes.com', data['author_url']
  end

  test "#oembed_url returns blank when no oembed data present in HTML" do
    oembed_url = Parser::PageItem.new('https://example.com').oembed_url(empty_doc)
    assert_nil oembed_url
  end

  test "#oembed_url returns oembed data from HTML when present" do
    oembed_url = Parser::PageItem.new('https://example.com').oembed_url(oembed_doc)
    assert_equal "https://example.com/oembed", oembed_url
  end
end
