require 'test_helper'

class PageItemUnitTest < ActiveSupport::TestCase
  def setup
    isolated_setup
    WebMock.stub_request(:post, /safebrowsing.googleapis.com/).to_return(status: 200, body: { matches: [] }.to_json )
    OembedItem.any_instance.stubs(:get_data).returns({})
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

  test "re-fetches HTML and re-sets metatags, following all redirects, if doc is empty" do
    url = 'https://example.com'
    RequestHelper.stubs(:get_html).with(url, kind_of(Method), {allow_redirections: :all}, false).returns(Nokogiri::HTML('<meta name="description" content="hello" />'))

    data = Parser::PageItem.new('https://example.com').parse_data(nil, 'https://example.com/original')
    assert_equal data.dig('raw', 'metatags').size, 1
    assert_equal data.dig('raw', 'metatags')[0]['content'], 'hello'
  end

  test "sets and reports error if HTML cannot be retrieved on second try" do
    RequestHelper.stubs(:get_html).returns(nil)

    data = {}
    sentry_call_count = 0
    arguments_checker = Proc.new do |e|
      sentry_call_count += 1
      assert_equal Parser::PageItem::HtmlFetchingError, e.class
    end

    PenderSentry.stub(:notify, arguments_checker) do
      data = Parser::PageItem.new('https://example.com').parse_data(nil, throwaway_url)
      assert_equal 1, sentry_call_count
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

  test "requests oembed data from URL in HTML and assigns returned data" do
    # Using different mocking library below, so need to unstub
    OembedItem.any_instance.unstub(:get_data)

    fake_oembed_item = Proc.new do |request_url, oembed_url|
      assert_equal 'https://example.com/oembed', oembed_url

      OpenStruct.new(get_data: {
        raw: {
          oembed: {
            author_name: 'Piglet McDog',
            summary: "She's a great pup",
            title: "Piglet's house",
            thumbnail_url: 'https://example.com/pig-small.jpg',
            html: '<div id="dog"></div>',
            author_url: 'https://example.com/pig-small.jpg',
          }
        }
      })
    end

    data = {}
    OembedItem.stub(:new, fake_oembed_item) do
      data = Parser::PageItem.new('https://example.com').parse_data(oembed_doc, throwaway_url)
    end

    assert !data['raw']['oembed'].empty?
    assert_nil data['raw']['oembed']['error']

    assert_equal '', data['published_at']
    assert_equal 'Piglet McDog', data['username']
    assert_equal "She's a great pup", data['description']
    assert_equal "Piglet's house", data['title']
    assert_equal "https://example.com/pig-small.jpg", data['picture']
    assert_equal '<div id="dog"></div>', data['html']
    assert_equal 'https://example.com/pig-small.jpg', data['author_url']
  end

  test "falls back to using title for description from oembed data when summary not available" do
    OembedItem.any_instance.stubs(:get_data).returns(
      {
        raw: {
          oembed: {
            title: "Piglet's house",
          }
        }
      }
    )
    data = Parser::PageItem.new('https://example.com').parse_data(oembed_doc, throwaway_url)

    assert_equal "Piglet's house", data['description']
  end

  test "does not set oembed data if there is an issue with returned oembed data" do
    OembedItem.any_instance.stubs(:get_data).returns(
      {
        raw: {
          oembed: {
            error: { some: 'error' },
            summary: "Piglet's house",
          }
        }
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
      <meta property="twitter:site" content="Piglet McDog's Blog"/>
    HTML
    data = Parser::PageItem.new('https://example.com').parse_data(doc, throwaway_url)

    assert_equal "Piglet's page", data['title']
    assert_equal 'http://example.com/image', data['picture']
    assert_equal 'A place for dogs, surprisingly', data['description']
    assert_equal "Piglet McDog's Blog", data['author_name']
  end

  test "does not set author_name from metadata if it's default username" do
    doc = Nokogiri::HTML(<<~HTML)
      <meta property="twitter:site" content="@username"/>
    HTML
    data = Parser::PageItem.new('https://example.com').parse_data(doc, throwaway_url)

    assert_nil data['author_name']
  end

  # Internal stubbing makes this brittle to changes in implementation, but want 
  # to reinforce this behavior and make clearer than is in other tests
  test "should not overwrite metatags with nil" do
    Parser::PageItem.any_instance.stubs(:get_metadata_from_tags).returns({description: "Something", title: "Meedan Checkdesk", username: "Tom", published_at: "", author_url: "https://meedan.checkdesk.org", picture: 'meedan.png'})
    Parser::PageItem.any_instance.stubs(:get_html_info).returns({ description: ""})
    Parser::PageItem.any_instance.stubs(:format_oembed_data).returns({})
    Parser::PageItem.any_instance.stubs(:get_opengraph_metadata).returns({author_url: nil})
    Parser::PageItem.any_instance.stubs(:get_twitter_metadata).returns({author_url: nil})

    data = Parser::PageItem.new('https://meedan.com').parse_data(empty_doc, throwaway_url)
    assert_match 'Meedan Checkdesk', data['title']
    assert_match 'Tom', data['username']
    assert_match '', data['description']
    assert_not_nil data['published_at']
    assert_match 'https://meedan.checkdesk.org', data['author_url']
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

  test "sets author name as author_name, username, and then title from Twitter metadata" do
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

  test "does not reassign url if cookies are required and present" do
    doc = Nokogiri::HTML('<meta property="pbContext" content="asdf"/>')
    parser = Parser::PageItem.new('https://example.com')
    data = parser.parse_data(doc, 'https://example.com/original')

    assert_equal 'https://example.com', parser.url
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
    assert_raises Pender::Exception::UnsafeUrl do
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
    assert_raises Pender::Exception::UnsafeUrl do
      Parser::PageItem.new('https://example.com/safeurl').parse_data(doc, throwaway_url)
    end

    # author_picture
    doc = Nokogiri::HTML(<<~HTML)
      <meta property="article:author" content="https://example.com/unsafeurl" />
    HTML
    assert_raises Pender::Exception::UnsafeUrl do
      Parser::PageItem.new('https://example.com/safeurl').parse_data(doc, throwaway_url)
    end

    # picture
    doc = Nokogiri::HTML(<<~HTML)
      <meta property="article:author" content="https://example.com/unsafeurl" />
    HTML
    assert_raises Pender::Exception::UnsafeUrl do
      Parser::PageItem.new('https://example.com/safeurl').parse_data(doc, throwaway_url)
    end
  end

  test "uses twitter URL from twitter metadata for author_url (and not username) if valid" do
    doc = Nokogiri::HTML(<<~HTML)
      <meta property="twitter:creator" content="@fakeaccount" />
    HTML
    
    data = Parser::PageItem.new('http://example.com').parse_data(doc, throwaway_url)
    
    assert_equal 'https://twitter.com/fakeaccount', data['author_url']
    assert_equal '@fakeaccount', data['username']
  end

  test "does not set author_url from twitter metadata if a default username, instead defaults to top URL" do
    api_response = response_fixture_from_file('twitter-profile-response-success.json', parse_as: :json)

    doc = Nokogiri::HTML(<<~HTML)
      <meta property="twitter:creator" content="@username" />
    HTML
    
    data = Parser::PageItem.new('http://lnphil.blogspot.com.br/2018/01/villar-at-duterte-nagsanib-pwersa-para.html').parse_data(doc, throwaway_url)
    assert_equal 'http://lnphil.blogspot.com.br', data['author_url']
    assert_not_equal '@username', data['username']
  end

  test "does not crash if it cannot determine whether site is safe " do
    WebMock.stub_request(:post, /safebrowsing.googleapis.com/).
      with(body: /example.com\/unsafeurl/).
      to_return(status: 200, body: "{}" )

    Parser::PageItem.new('https://example.com/unsafeurl').parse_data(empty_doc, throwaway_url)
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

  test "shouldn't break when username is a bad username" do
  # I'm trying to write a substitute to "should handle error when cannot get twitter url"
  # Not too sure about this yet
    Parser::PageItem.stubs(:get_twitter_metadata).returns(nil)
    
    data = Parser::PageItem.new('https://random-page.com/page-item').parse_data(empty_doc)

    assert data['error'].nil?
    assert_equal "https://random-page.com", data['author_url']
  end
end
