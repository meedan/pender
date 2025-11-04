require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'stringio'

class MediaTest < ActiveSupport::TestCase
  test "should create media" do
    assert_kind_of Media, create_media
  end

  test "should normalize URL" do
    variations = %w(
      https://meedan.com
      meedan.com
      https://meedan.com:443
      https://meedan.com//
      https://meedan.com/?
      https://meedan.com/#foo
      https://meedan.com/
      https://meedan.com
      https://meedan.com/foo/..
      https://meedan.com/?#
    )
    variations.each do |url|
      media = Media.new(url: url)
      assert_equal 'https://meedan.com/', media.url
    end
  end

  test "should not normalize URL" do
    urls = %w(
      https://meedan.com/
      https://example.com/
      https://meedan.com/?foo=bar
    )
    urls.each do |url|
      media = Media.new(url: url)
      assert_equal url, media.url
    end
  end

  test "should follow redirection of relative paths" do
    WebMock.enable!
    WebMock.stub_request(:any, /https?:\/\/www.almasryalyoum.com\/node\/517699/).to_return(body: '', headers: { location: '/editor/details/968' }, status: 302)
    Media.any_instance.stubs(:get_canonical_url).returns(false)
    m = create_media url: 'https://www.almasryalyoum.com/node/517699'
    assert_match /almasryalyoum.com\/editor\/details\/968/, m.url
    WebMock.disable!
  end

  test "should parse URL including cloudflare credentials on header" do
      host = ENV['hosts']
      url = 'https://example.com/'
      parsed_url = RequestHelper.parse_url url
      m = Media.new url: url
      header_options_without_cf = RequestHelper.html_options(url).merge(read_timeout: PenderConfig.get('timeout', 30).to_i)
      assert_nil header_options_without_cf['CF-Access-Client-Id']
      assert_nil header_options_without_cf['CF-Access-Client-Secret']

      PenderConfig.current = nil
      ENV['hosts'] = {"example.com"=>{"cf_credentials"=>"1234:5678"}}.to_json
      header_options_with_cf = RequestHelper.html_options(url).merge(read_timeout: PenderConfig.get('timeout', 30).to_i)
      assert_equal '1234', header_options_with_cf['CF-Access-Client-Id']
      assert_equal '5678', header_options_with_cf['CF-Access-Client-Secret']
      URI.stubs(:open).with(parsed_url, header_options_without_cf).raises(RuntimeError.new('unauthorized'))
      URI.stubs(:open).with(parsed_url, header_options_with_cf)
      assert_equal Nokogiri::HTML::Document, m.send(:get_html, RequestHelper.html_options(m.url)).class
  ensure
    ENV['hosts'] = host
  end

  test "should get relative canonical URL parsed from html tags" do
    m = create_media url: 'https://www.bbc.com'
    data = m.process_and_return_json
    assert_match 'https://www.bbc.com', m.url
    assert_match 'BBC', data['title']
    assert_kind_of String, data['description']
    assert_equal '', data['published_at']
    assert_equal '', data['username']
    assert_equal 'https://www.bbc.com', data['author_url']
    assert_equal '', data['picture']
  end

  test "should get canonical URL parsed from html tags" do
    doc = ''
    File.open('test/data/page-with-url-on-tag.html') { |f| doc = f.read }
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML(doc))

    media1 = create_media url: 'http://example.com/2016/08/bom-dia-2.html'
    media2 = create_media url: 'http://example.com/?p=6704&fake=123'
    assert_equal media1.url, media2.url
    Media.any_instance.unstub(:doc)
  end

  test "should store the picture address" do
    m = create_media url: 'http://xkcd.com/448/'
    data = m.process_and_return_json
    assert_match /Good Morning/, data['title']
    assert_equal 'https://xkcd.com/448/', data['description']
    assert_equal '', data['published_at']
    assert_equal '', data['username']
    assert_match 'https://xkcd.com', data['author_url']
    assert_equal '', data['screenshot']
    assert data['picture'].present?
  end

  test "should return author picture" do
    WebMock.stub_request(:get, /github.com/).to_return(status: 200, body: "<meta property='og:image' content='https://github.githubassets.com/images/modules/open_graph/github-logo.png'>")
    url = 'https://github.com/'
    m = create_media url: url
    id = Media.cache_key m.url
    data = m.process_and_return_json
    assert_match /\/medias\/#{id}\/author_picture/, data['author_picture']
  end

  test 'should log parser information when parsing a new URL' do
    url = 'https://x.com/search?q=twitter'
    media = Media.new(url: url)

    log = StringIO.new
    Rails.logger = Logger.new(log)

    media.process_and_return_json

    assert_match '[Parser] Parsing new URL', log.string
    assert_match url, log.string
    assert_match media.type, log.string
  end

  test "should handle connection reset by peer error" do
    url = 'https://br.yahoo.com/'
    parsed_url = RequestHelper.parse_url(url)
    URI.stubs(:open).raises(Errno::ECONNRESET)
    m = create_media url: url
    assert_nothing_raised do
      m.send(:get_html, RequestHelper.html_options(m.url))
    end
  end

  test "should handle zlib error when opening a url" do
    m = create_media url: 'https://ca.yahoo.com'
    parsed_url = RequestHelper.parse_url( m.url)
    header_options = RequestHelper.html_options(m.url).merge(read_timeout: PenderConfig.get('timeout', 30).to_i)
    URI.stubs(:open).with(parsed_url, header_options).raises(Zlib::DataError)
    URI.stubs(:open).with(parsed_url, header_options.merge('Accept-Encoding' => 'identity'))
    m.send(:get_html, RequestHelper.html_options(m.url))
    OpenURI.unstub(:open_uri)
  end

  test "should handle zlib buffer error when opening a url" do
    m = create_media url: 'https://www.businessdailyafrica.com/'
    parsed_url = RequestHelper.parse_url( m.url)
    header_options = RequestHelper.html_options(m.url).merge(read_timeout: PenderConfig.get('timeout', 30).to_i)
    URI.stubs(:open).with(parsed_url, header_options).raises(Zlib::BufError)
    URI.stubs(:open).with(parsed_url, header_options.merge('Accept-Encoding' => 'identity'))
    m.send(:get_html, RequestHelper.html_options(m.url))
    OpenURI.unstub(:open_uri)
  end

  test "should not notify Sentry when it is a redirection from https to http" do
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)

    m = create_media url: 'https://www.scmp.com/news/china/diplomacy-defence/article/2110488/china-tries-build-bigger-bloc-stop-brics-crumbling'
    parsed_url = RequestHelper.parse_url(m.url)
    header_options = RequestHelper.html_options(m.url).merge(read_timeout: PenderConfig.get('timeout', 30).to_i)
    URI.stubs(:open).with(parsed_url, header_options).raises('redirection forbidden')

    m.send(:get_html, header_options)
  end

  test "should redirect to HTTPS if available and not already HTTPS" do
    m = create_media url: 'http://imotorhead.com'
    assert_match 'https://imotorhead.com', m.url
  end

  test "should not redirect to HTTPS if available and already HTTPS" do
    m = create_media url: 'https://imotorhead.com'
    assert_match 'https://imotorhead.com', m.url
  end

  test "should not redirect to HTTPS if not available" do
    url = 'http://www.angra.net/website'
    https_url = 'https://www.angra.net/website'
    WebMock.enable!
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html></html>')
    response = 'mock'; response.stubs(:code).returns(200)
    RequestHelper.stubs(:request_url).with(url, 'Get').returns(response)
    RequestHelper.stubs(:request_url).with(https_url, 'Get').raises(OpenSSL::SSL::SSLError)
    m = create_media url: url
    assert_equal 'http://www.angra.net/website', m.url
    WebMock.disable!
  end

  test "should return empty html on oembed when frame is not allowed" do
    m = create_media url: 'http://meedan.com/'
    data = m.process_and_return_json
    assert_equal '', data['html']
  end

  test "should keep port when building author_url if port is not 443 or 80" do
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:data_from_page_item)

    url = 'https://mediatheque.karimratib.me:5001/as/sharing/uhfxuitn'
    m = create_media url: url
    assert_equal 'https://mediatheque.karimratib.me:5001', RequestHelper.top_url(m.url)

    url = 'https://meedan.com/en/check'
    m = create_media url: url
    assert_equal 'https://meedan.com', RequestHelper.top_url(m.url)
  end

  test "should not return empty values on metadata keys due to bad html" do
    m = create_media url: 'http://www.politifact.com/truth-o-meter/article/2017/may/09/year-fact-checking-about-james-comey-clinton-email/'
    html = '<meta charset="utf-8">
    <meta http-equiv="x-ua-compatible" content="ie=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta property="og:description" content="James Comey is out as FBI director. "While I greatly appreciate you informing me">'
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML(html))
    tag_description = m.process_and_return_json['raw']['metatags'].find { |tag| tag['property'] == 'og:description'}
    assert_equal ['property', 'content'], tag_description.keys
    assert_match /\AJames Comey is out as FBI director.\z/, tag_description['content']
  end

  test "should store json+ld data as an array of hashes" do
    m = create_media url: 'http://www.example.com'
    doc = ''
    File.open('test/data/page-with-json-ld.html') { |f| doc = f.read }
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML(doc))
    data = m.process_and_return_json

    assert_not_empty data['raw']['json+ld']
    assert_kind_of Array, data['raw']['json+ld']
    assert_kind_of Hash, data['raw']['json+ld'].first
  end

  test "should handle errors when call parse on each parser" do
    Media.any_instance.stubs(:get_oembed_data)
    Media::PARSERS.each do |parser|
      parser.any_instance.stubs(:parse_data).raises(StandardError)
    end

    # If we stub within this block, the stub isn't in place when we need it
    Media::PARSERS.each do |parser|
      m = create_media url: 'http://example.com'
      data = m.process_and_return_json
      assert_equal "StandardError: StandardError", data['error']['message']
    end
  end

  test "should request URL with User-Agent on header" do
    url = 'https://globalvoices.org/2019/02/16/nigeria-postpones-2019-general-elections-hours-before-polls-open-citing-logistics-and-operations-concerns'
    uri = RequestHelper.parse_url(url)
    WebMock.enable!
    WebMock.stub_request(:get, url).with(headers: {'User-Agent' => RequestHelper.html_options(uri)['User-Agent'], 'Accept-Language' => 'en-US;q=0.6,en;q=0.4'}).to_return(body: 'success', status: 200)

    assert_equal 'success', RequestHelper.request_url(url, 'Get').body
  ensure
    WebMock.disable!
  end

  test "should add cookie from config on header if domain matches" do
    stub_configs(cookies: { '.example.com' => { 'wp_devicetype' => '0' } })

    url_no_cookie = 'https://www.istqb.org/'
    assert_equal "", RequestHelper.html_options(url_no_cookie)['Cookie']
    url_with_cookie = 'https://example.com/politics/winter-is-coming-allies-fear-trump-isnt-prepared-for-gathering-legal-storm/2018/08/29/b07fc0a6-aba0-11e8-b1da-ff7faa680710_story.html'
    assert_match "wp_devicetype=0", RequestHelper.html_options(url_with_cookie)['Cookie']
  end

  test "should rescue error on set_cookies" do
    uri = RequestHelper.parse_url('https://www.bbc.com/')
    PublicSuffix.stubs(:parse).with(uri.host).raises
    assert_equal "", RequestHelper.set_cookies(uri)
  end

  test "should use cookies from api key config if present" do
    stub_configs(cookies: { '.example.com' => { 'wp_devicetype' => '0' } })

    api_key = create_api_key
    uri = RequestHelper.parse_url('http://example.com')

    assert_not_includes PenderConfig.get('cookies').keys, 'example.com'
    assert_equal PenderConfig.get('cookies')['.example.com'].map { |k, v| "#{k}=#{v}"}.first, RequestHelper.set_cookies(uri)

    PenderConfig.current = nil
    ApiKey.current = api_key
    assert_equal PenderConfig.get('cookies')['.example.com'].map { |k, v| "#{k}=#{v}"}.first, RequestHelper.set_cookies(uri)

    api_key.application_settings = { config: { cookies: { 'example.com' => { "example_cookies" => "true", "devicetype"=>"0" }}}}
    api_key.save
    PenderConfig.current = nil
    ApiKey.current = api_key
    assert_equal "example_cookies=true; devicetype=0", RequestHelper.set_cookies(uri)
  end

  test "should use specific country on proxy for domains on hosts" do
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:parse)

    country = 'gb'
    config = {
      'hosts' => {'time.com' => { 'country' => country }}.to_json,
      'proxy_host' => 'proxy.pender',
      'proxy_port' => '11111',
      'proxy_user_prefix' => 'user-prefix-static',
      'proxy_pass' => 'password',
      'proxy_country_prefix' => '-country-',
      'proxy_session_prefix' => '-session-'
    }
    api_key = create_api_key application_settings: { config: config }
    m = create_media url: 'http://time.com/5058736/climate-change-macron-trump-paris-conference/', key: api_key

    host, user, pass = RequestHelper.get_proxy(RequestHelper.parse_url(m.url))
    assert_match config['proxy_host'], host
    assert_match "#{config['proxy_user_prefix']}#{config['proxy_country_prefix']}#{country}", user
    assert_equal config['proxy_pass'], pass

    data = m.process_and_return_json
    assert_equal m.url, data['title']
  end

  test "should use data from api key to set proxy" do
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:parse)
    a = create_api_key application_settings: { config: { hosts: { 'example.com': { country: 'gb'}}.to_json, proxy_host: 'my-host', proxy_port: '11111', proxy_user_prefix: 'my-user-prefix', proxy_country_prefix: '-cc-', proxy_session_prefix: '-sid-', proxy_pass: 'mypass' }}

    m = create_media url: 'http://example.com', key: a
    host, user, pass = RequestHelper.get_proxy(RequestHelper.parse_url(m.url))
    assert_match 'http://my-host:11111', host
    assert_match 'my-user-prefix-cc-gb', user
    assert_equal 'mypass', pass
  end

  test "should return nil as proxy if missing any config info" do
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:parse)
    a = create_api_key application_settings: { config: { hosts: { 'example.com': { country: 'gb'}}.to_json, proxy_host: 'my-host', proxy_port: '11111', proxy_user_prefix: '', proxy_country_prefix: '', proxy_session_prefix: '', proxy_pass: '' }}

    m = create_media url: 'http://example.com', key: a
    assert_nil RequestHelper.get_proxy(RequestHelper.parse_url(m.url))
  end

  test "should not replace sharethefacts url if the sharethefacts js is not present" do
    urls = %w(
      https://twitter.com/sharethefact/status/1067835775000215553
      https://twitter.com/factcheckdotorg
    )
    urls.each do |url|
      m = Media.new url: url
      HtmlPreprocessor.stubs(:sharethefacts_replace_element).returns('replaced data')
      assert_nothing_raised do
        assert_no_match /replaced data/, m.send(:get_html, RequestHelper.html_options(m.url))
        m.process_and_return_json
      end
    end
  end

  test "should match correctly the share the facts url when preprocess html" do
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)

    WebMock.enable!
    WebMock.stub_request(:get, 'https://dhpikd1t89arn.cloudfront.net/html-0636d2f1-39c5-45b8-b061-db61b4fd0024.html').to_return(body: 'share the facts', status: 200)

    m = Media.new url: 'http://www.example.com'
    html = '<a href="https://t.co/tLSGfdxUQr" data-expanded-url="http://factcheck.sharethefacts.co/share/0636d2f1-39c5-45b8-b061-db61b4fd0024" ><span class="tco-ellipsis"></span><span class="invisible">http://</span><span class="js-display-url">factcheck.sharethefacts.co/share/0636d2f1</span><span class="invisible">-39c5-45b8-b061-db61b4fd0024</span><span class="tco-ellipsis"><span class="invisible">&nbsp;</span>…</span></a>'
    assert_equal '<div>share the facts</div>', HtmlPreprocessor.send(:find_sharethefacts_links, html)
  ensure
    WebMock.disable!
  end

  test "should update media cache" do
    url = 'http://www.example.com'
    m = create_media url: url
    id = Media.cache_key(m.url)
    m.process_and_return_json

    assert_equal({}, Pender::Store.current.read(id, :json)['archives'])
    Media.update_cache(m.url, { archives: { 'archive_org' => 'new-data' } })
    assert_equal({'archive_org' => 'new-data'}, Pender::Store.current.read(id, :json)['archives'])
  end

  test "should add error on raw oembed and generate the default oembed when can't parse oembed" do
    oembed_response = 'mock'
    oembed_response.stubs(:code).returns('200')
    error = '<br />\n<b>Warning</b>: {\"version\":\"1.0\"}'
    oembed_response.stubs(:body).returns(error)
    OembedItem.any_instance.stubs(:get_oembed_data_from_url).returns(oembed_response)

    url = 'https://example.com'
    m = create_media url: url
    data = m.process_and_return_json
    assert_match error, data[:raw][:oembed]['error']['message']
    assert_match(/Example Domain/, data['oembed']['title'])
    assert_equal 'page', data['oembed']['provider_name']
  end

  test "should follow redirections of path relative urls" do
    url = 'https://www.yousign.org/China-Lunatic-punches-dog-to-death-in-front-of-his-daughter-sign-now-t-4358'
    WebMock.enable!
    WebMock.stub_request(:any, 'https://www.yousign.org/China-Lunatic-punches-dog-to-death-in-front-of-his-daughter-sign-now-t-4358').to_return(body: '', headers: { location: 'v2_404.php?notfound=%2FChina-Lunatic-punches-dog-to-death-in-front-of-his-daughter-sign-now-t-4358' }, status: 302)
    Media.any_instance.stubs(:get_canonical_url).returns(false)
    m = create_media url: url
    assert_equal 'https://www.yousign.org/v2_404.php?notfound=/China-Lunatic-punches-dog-to-death-in-front-of-his-daughter-sign-now-t-4358', m.url
    WebMock.disable!
  end

  test "should not reach the end of file caused by User-Agent" do
    m = create_media url: 'https://www.nbcnews.com/'
    parsed_url = RequestHelper.parse_url m.url
    header_options = RequestHelper.html_options(m.url).merge(read_timeout: PenderConfig.get('timeout', 30).to_i)
    URI.stubs(:open).with(parsed_url, header_options.merge('User-Agent' => 'Mozilla/5.0', 'Accept-Language' => 'en-US;q=0.6,en;q=0.4')).raises(EOFError)
    URI.stubs(:open).with(parsed_url, header_options.merge('User-Agent' => 'Mozilla/5.0 (X11)', 'Accept-Language' => 'en-US;q=0.6,en;q=0.4'))
    assert_nothing_raised do
      m.send(:get_html, header_options)
    end
  end

  test "should not reach the end of file caused by Net::Http::Proxy" do
    logger_output = StringIO.new
    Rails.logger = Logger.new(logger_output)
    m = create_media url: 'https://www.nbcnews.com/'
    parsed_url = RequestHelper.parse_url(m.url)
    header_options = RequestHelper.html_options(m.url).merge(read_timeout: PenderConfig.get('timeout', 30).to_i)
    URI.stubs(:open).with(parsed_url, header_options).raises(EOFError)
    assert_nothing_raised do
      m.send(:get_html, header_options)
    end
    assert_includes logger_output.string, "[Parser] Could not get html"
  end

  test "should not throw read time out errors caused by Net::Http::Proxy" do
    logger_output = StringIO.new
    Rails.logger = Logger.new(logger_output)
    m = create_media url: 'https://www.nbcnews.com/'
    parsed_url = RequestHelper.parse_url(m.url)
    header_options = RequestHelper.html_options(m.url).merge(read_timeout: PenderConfig.get('timeout', 30).to_i)
    URI.stubs(:open).with(parsed_url, header_options).raises(Net::ReadTimeout)
    assert_nothing_raised do
      m.send(:get_html, header_options)
    end
    assert_includes logger_output.string, "[Parser] Could not get html"
  end

  test "should parse page when json+ld tag content is an empty array" do
    url = 'https://www.example.com/'
    WebMock.enable!
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML('<script data-rh="true" type="application/ld+json">[]</script>'))
    m = create_media url: url
    data = m.process_and_return_json
    assert_equal url, data['url']
    assert_nil data['error']
    WebMock.disable!
  end

  test "should not raise encoding error when saving data" do
    url = 'https://bastitimes.page/article/raajy-sarakaaren-araajak-tatvon-ke-viruddh-karen-kathoratam-kaarravaee-sonoo-jha/5CvP5F.html'
    data_with_encoding_error = {"published_at"=>"", "description"=>"कर\xE0\xA5", "raw"=>{"metatags"=>[{"content"=>"कर\xE0\xA5"}]}, "schema"=>{"NewsArticle"=>[{"author"=>[{"name"=>"कर\xE0\xA5"}], "headline"=>"कर\xE0\xA5", "publisher"=>{"@type"=>"Organization", "name"=>"कर\xE0\xA5"}}]}, "oembed"=>{"type"=>"rich", "version"=>"1.0", "title"=>"कर\xE0\xA5"}}
    WebMock.enable!
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html></html>')

    m = create_media url: url
    Media.any_instance.stubs(:data).returns(data_with_encoding_error)
    Media.any_instance.stubs(:parse)

    assert_raises JSON::GeneratorError do
      Pender::Store.current.write(Media.cache_key(m.original_url), :json, data_with_encoding_error)
    end

    assert_nothing_raised do
      data = m.process_and_return_json
      assert_equal "कर�", data['description']
      assert_equal "कर�", data['oembed']['title']
      assert_equal "कर�", data['raw']['metatags'].first['content']
      assert_equal "कर�", data['schema']['NewsArticle'].first['headline']
      assert_equal "कर�", data['schema']['NewsArticle'].first['author'].first['name']
      assert_equal "कर�", data['schema']['NewsArticle'].first['publisher']['name']
    end
    WebMock.disable!
  end

  test "should not change media url if url parsed on metatags is not valid" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML("<meta property='og:url' content='aosfatos.org/noticias/em-video-difundido-por-trump-medica-engana-ao-dizer-que-cloroquina-cura-covid19'>"))
    url = 'https://www.aosfatos.org/noticias/em-video-difundido-por-trump-medica-engana-ao-dizer-que-cloroquina-cura-covid19'
    m = Media.new url: url
    m.process_and_return_json
    assert_equal url, m.url
  end

  test "should ignore metatag when content is not present" do
    Media.any_instance.stubs(:follow_redirections)
    RequestHelper.stubs(:get_html).returns(Nokogiri::HTML("<meta property='og:url' />"))
    url = 'https://www.mcdonalds.com/'
    m = Media.new url: url
    m.process_and_return_json
    assert_equal url, m.url
  end

  test "should return url on title when title is blank" do
    Media.any_instance.stubs(:doc).returns(nil)
    url = 'http://example.com/empty-page'
    m = Media.new url: url
    data = m.process_and_return_json
    assert_equal url, data['title']
  end

  test "should handle forbidden error when opening a url and parse with proxy without loop" do
    m = create_media url: 'https://nasional.tempo.co/read/1457804/opm-kkb-dicap-teroris-amnesty-nilai-pemerintah-tak-paham-masalah-papua'
    parsed_url = RequestHelper.parse_url(m.url)
    header_options = RequestHelper.html_options(m.url).merge(read_timeout: PenderConfig.get('timeout', 30).to_i)
    URI.stubs(:open).with(parsed_url, header_options).raises(OpenURI::HTTPError.new('','403 Forbidden'))
    header_with_proxy = { proxy_http_basic_authentication: RequestHelper.get_proxy(RequestHelper.parse_url(m.url), :array, true), 'Accept-Language' => Media::LANG, read_timeout: PenderConfig.get('timeout', 30).to_i }
    URI.stubs(:open).with(parsed_url, header_with_proxy).raises(OpenURI::HTTPError.new('','403 Forbidden'))
    m.send(:get_html, RequestHelper.html_options(m.url))
  end
end

class MediaUnitTest < ActiveSupport::TestCase
  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  test "should cache on successful parse" do
    WebMock.stub_request(:get, /example.com/).and_return(status: 200, body: '<html>something</html>')
    Parser::PageItem.any_instance.stubs(:parse_data).returns({title: 'a title'})

    url = 'http://www.example.com/'
    m = create_media url: url
    id = Media.cache_key(m.url)

    Pender::Store.current.delete(id, :json)
    assert Pender::Store.current.read(id, :json).blank?

    data = m.process_and_return_json

    assert_equal data[:title], 'a title'
    assert_equal Pender::Store.current.read(id, :json)[:title], 'a title'
  end

  test "should not cache when top-level error" do
    WebMock.stub_request(:get, /example.com/).and_return(status: 200, body: '<html>something</html>')
    Parser::PageItem.any_instance.stubs(:parse_data).returns({title: 'a title', error: {message: 'fake error for test'}})

    url = 'http://www.example.com'
    m = create_media url: url
    id = Media.cache_key(m.url)

    Pender::Store.current.delete(id, :json)
    assert Pender::Store.current.read(id, :json).blank?

    data = m.process_and_return_json

    assert Pender::Store.current.read(id, :json).blank?
  end

  test "should still return uncoded data on error" do
    WebMock.stub_request(:get, /example.com/).and_return(status: 200, body: '<html>something</html>')
    Parser::PageItem.any_instance.stubs(:parse_data).returns({title: 'this is a title', raw: {link: 'https://www.example.com/á<80><99>á<80><84>á<80>'}, error: {message: 'fake error for test'}})

    url = 'http://www.example.com'

    m = create_media url: url
    id = Media.cache_key(m.url)

    Pender::Store.current.delete(id, :json)
    assert Pender::Store.current.read(id, :json).blank?

    data = m.process_and_return_json

    assert Pender::Store.current.read(id, :json).blank?
    assert_equal 'this is a title', data[:title]
    assert_equal 'https://www.example.com/%C3%A1%3C80%3E%3C99%3E%C3%A1%3C80%3E%3C84%3E%C3%A1%3C80%3E', data[:raw][:link]
  end

  test "#notify_webhook should raise a retry exception for unsuccessful response from webhook" do
    WebMock.stub_request(:post, /example.com/).and_return(status: 404, body: 'fake response body')
    webhook_info = { 'webhook_url' => 'http://example.com/webhook', 'webhook_token' => 'test' }

    assert_raises Pender::Exception::RetryLater do
      Media.notify_webhook('archive.org', 'http://example.com', {}, webhook_info)
    end
  end

  test "#notify_webhook should swallow exception and report error to errbit if error happens while notifying webhook" do
    WebMock.stub_request(:post, /example.com/).and_return(status: 200, body: 'fake response body')
    webhook_info = { 'webhook_url' => 'asdfasdf', 'webhook_token' => 'test' }

    sentry_call_count = 0
    arguments_checker = Proc.new do |e|
      sentry_call_count += 1
    end

    PenderSentry.stub(:notify, arguments_checker) do
      assert_nothing_raised do
        Media.notify_webhook('archive.org', 'http://example.com', {}, webhook_info)
      end
    end
    assert_equal 1, sentry_call_count
  end

  test "#notify_webhook should return successful response from webhook" do
    webhook_info = { 'webhook_url' => 'http://example.com/webhook', 'webhook_token' => 'test' }

    WebMock.stub_request(:post, /example.com/).and_return(status: 200, body: 'fake response body')
    response = Media.notify_webhook('archive.org', 'http://example.com', {}, webhook_info)
    assert_equal "200", response.code
    assert_equal 'fake response body', response.body

    WebMock.stub_request(:post, /example.com/).and_return(status: 201, body: 'fake response body')
    response = Media.notify_webhook('archive.org', 'http://example.com', {}, webhook_info)
    assert_equal "201", response.code
    assert_equal 'fake response body', response.body
  end

  test 'should remove parser specific URL parameters' do
    url = 'https://www.instagram.com/p/xyz/?igsh=1'
    WebMock.stub_request(:any, url).to_return(status: 200, body: 'fake response body')

    media = Media.new(url: url)
    assert_not_includes media.url, 'igsh'
    assert_equal media.url, 'https://www.instagram.com/p/xyz'
  end

  test 'should remove parser specific URL parameters when URL contains multiple parameters' do
    url = 'https://www.instagram.com/p/xyz/?param1=value1&igsh=1&param2=value2'
    WebMock.stub_request(:any, url).to_return(status: 200, body: 'fake response body')

    media = Media.new(url: url)
    assert_not_includes media.url, 'igsh'
    assert_equal media.url, 'https://www.instagram.com/p/xyz?param1=value1&param2=value2'
  end

  test 'invalid image URL should not stop an item from being parsed' do
    WebMock.stub_request(:get, /example.com/).and_return(status: 200, body: 'fake response body')
    Parser::PageItem.any_instance.stubs(:parse_data).returns({ picture: 'http://{image}' })

    m = create_media url: 'http://www.example.com'
    assert_nothing_raised do
      m.process_and_return_json force: true
    end
  end
end
