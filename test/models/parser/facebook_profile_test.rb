require 'test_helper'

class FacebookProfileUnitTest < ActiveSupport::TestCase
  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  # Standard profile page
  def meedan_doc
    @meedan_doc ||= response_fixture_from_file('facebook-profile-page_meedan.html', parse_as: :html)
  end

  # Standard profile page, but in Arabic
  def arabic_doc
    @arabic_doc ||= response_fixture_from_file('facebook-profile-page_arabic.html', parse_as: :html)
  end

  # Old format profile page
  def old_meedan_doc
    @old_meedan_doc ||= response_fixture_from_file('facebook-profile-page_meedan-old.html', parse_as: :html)
  end

  # HTML when login is required (redirect or not)
  def login_doc
    @login_doc ||= response_fixture_from_file('facebook-profile-page_login.html', parse_as: :html)
  end

  def empty_doc
    @empty_doc ||= Nokogiri::HTML('')
  end

  def throwaway_url
    'https://facebook.com/throwaway-url'
  end

  test "returns provider and type" do
    assert_equal Parser::FacebookProfile.type, 'facebook_profile'
  end

  # Note: Not all of these URLs can be visited successfully without logging in
  test "matches known URL patterns, and returns instance on success" do    
    assert Parser::FacebookProfile.match?('https://facebook.com/heymeedan').is_a?(Parser::FacebookProfile)
    assert Parser::FacebookProfile.match?('https://m.facebook.com/heymeedan').is_a?(Parser::FacebookProfile)
    assert Parser::FacebookProfile.match?('https://www.facebook.com/heymeedan').is_a?(Parser::FacebookProfile)
    assert Parser::FacebookProfile.match?('https://www.facebook.com/123456789').is_a?(Parser::FacebookProfile)
    assert Parser::FacebookProfile.match?('https://m.facebook.com/pages/Meedan/105510962816034?fref=ts').is_a?(Parser::FacebookProfile)
    assert Parser::FacebookProfile.match?('https://www.facebook.com/pages/Meedan/105510962816034?fref=ts').is_a?(Parser::FacebookProfile)
    assert Parser::FacebookProfile.match?('https://www.facebook.com/people/Meedan/105510962816034?fref=ts').is_a?(Parser::FacebookProfile)
    assert Parser::FacebookProfile.match?('https://www.facebook.com/profile.php?id=105510962816034').is_a?(Parser::FacebookProfile)
  end
  
  test "should not match patterns from Facebook items" do
    assert_nil Parser::FacebookProfile.match?('https://www.facebook.com/pages/Meedan/105510962816034/photos/')
    assert_nil Parser::FacebookProfile.match?('https://m.facebook.com/permalink.php?story_fbid=10154534111016407&id=54212446406')
    assert_nil Parser::FacebookProfile.match?('https://www.facebook.com/permalink.php?story_fbid=10154534111016407&id=54212446406')
    assert_nil Parser::FacebookProfile.match?('https://www.facebook.com/story.php?story_fbid=10154534111016407&id=54212446406')
    assert_nil Parser::FacebookProfile.match?('https://www.facebook.com/photo.php?story_fbid=10154534111016407&id=54212446406')
    assert_nil Parser::FacebookProfile.match?('https://www.facebook.com/livemap?story_fbid=10154534111016407&id=54212446406')
    assert_nil Parser::FacebookProfile.match?('https://www.facebook.com/watch?story_fbid=10154534111016407&id=54212446406')
  end
  
  test "should not match a page that isn't a Facebook page" do
    assert_nil Parser::FacebookProfile.match?('https://example.com')
  end

  test "should parse Facebook page" do
    parser = Parser::FacebookProfile.new('https://facebook.com/fakeaccount')
    data = parser.parse_data(meedan_doc, throwaway_url)

    assert_equal 'Meedan', data['title']
    assert_equal 'fakeaccount', data['username']
    assert_equal 'Meedan. 3,783 likes · 65 were here. Make sense of the global web.', data['description']
    assert_equal '54421674438', data['external_id']
    assert_equal '54421674438', data['id']
  end

  # following the redirections and setting the url to canonical happen in Media
  test "should parse Facebook with numeric id and set data['url'] to the canonical url" do
    url = 'https://facebook.com/513415662050479'
    canonical_url = 'https://www.facebook.com/heymeedan'
    picture_url = 'https://scontent-lax3-1.xx.fbcdn.net/v/t39.30808-1/310513247_435753678699138_2623398131510754475_n.png?_nc_cat=110&_nc_ht=scontent-lax3-1.xx&_nc_ohc=d6UgzKKHMJ8AX9tPN2o&_nc_sid=d36de4&ccb=1-7&oe=63DDB83C&oh=00_AfDH7lP98qp_etN0a2ZMms1tp6vx51198IAobPHbRLnSyA'
    
    WebMock.stub_request(:get, url).to_return(status: 200, body: meedan_doc.to_s)
    WebMock.stub_request(:get, canonical_url).to_return(status: 200)
    WebMock.stub_request(:get, "https://www.facebook.com/plugins/post/oembed.json/?url=#{canonical_url}").to_return(status: 200)
    WebMock.stub_request(:get, picture_url).to_return(status: 200)

    media = create_media url: url
    data = media.as_json

    assert_equal canonical_url, data['url']
    assert_equal 'Meedan', data['title']
    assert_equal 'facebook', data['provider']
    assert_equal 'profile', data['type']

    # Parsed from URL
    assert_equal '513415662050479', data['id']
    assert_equal '513415662050479', data['external_id']
  end

  test "should parse Arabic Facebook page" do
    parser = Parser::FacebookProfile.new('https://www.facebook.com/%D8%A7%D9%84%D9%85%D8%B1%D9%83%D8%B2-%D8%A7%D9%84%D8%AB%D9%82%D8%A7%D9%81%D9%8A-%D8%A7%D9%84%D9%82%D8%A8%D8%B7%D9%8A-%D8%A7%D9%84%D8%A3%D8%B1%D8%AB%D9%88%D8%B0%D9%83%D8%B3%D9%8A-%D8%A8%D8%A7%D9%84%D9%85%D8%A7%D9%86%D9%8A%D8%A7-179240385797/')
    data = parser.parse_data(arabic_doc, throwaway_url)
  
    assert_equal 'المركز الثقافي القبطي الأرثوذكسي بالمانيا', data['title']
    assert_equal 'المركز-الثقافي-القبطي-الأرثوذكسي-بالمانيا-179240385797', data['username']
    assert_match /Bad Kreuznach/ , data['description']
    assert_equal '179240385797', data['external_id']
    assert_equal '179240385797', data['id']
  end

  test "should parse Arabic URLs" do
    parser = Parser::FacebookProfile.new('https://www.facebook.com/إدارة-تموين-أبنوب-217188161807938/')
    data = parser.parse_data(arabic_doc, throwaway_url)
  
    assert_equal 'المركز الثقافي القبطي الأرثوذكسي بالمانيا', data['title']
    assert_equal 'إدارة-تموين-أبنوب-217188161807938', data['username']
    assert_match /Bad Kreuznach/ , data['description']
    assert_equal '179240385797', data['external_id']
    assert_equal '179240385797', data['id']
  end

  test "sets error if problem parsing and notifies Sentry" do
    data = {}
    sentry_call_count = 0
    arguments_checker = Proc.new do |e|
      sentry_call_count += 1
      assert_equal NoMethodError, e.class
    end

    Parser::FacebookProfile.stub(:get_id_from_doc, -> (_) { raise NoMethodError.new('fake for test') }) do
      PenderSentry.stub(:notify, arguments_checker) do
        parser = Parser::FacebookProfile.new('https://www.facebook.com/fakeaccount')
        data = parser.parse_data(nil, 'https://www.facebook.com/fakeaccount')
        assert_equal 1, sentry_call_count
      end
    end
    assert_match /NoMethodError/, data[:error][:message]
  end

  test "sets error if login page URL detected" do
    parser = Parser::FacebookProfile.new('https://www.facebook.com/login/?next=')
    data = parser.parse_data(meedan_doc, 'https://www.facebook.com/login/?next=')

    assert_equal Lapis::ErrorCodes::const_get('LOGIN_REQUIRED'), data[:error][:code]
    assert_match /Login required/, data[:error][:message]
    assert data['title'].nil?
    assert data['description'].empty?
  end

  test "sets error if login page detected from HTML, but not apparent from URL" do
    parser = Parser::FacebookProfile.new('https://facebook.com/fakeaccount')
    data = parser.parse_data(login_doc, 'https://facebook.com/fakeaccount')

    assert_equal Lapis::ErrorCodes::const_get('LOGIN_REQUIRED'), data[:error][:code]
    assert_match /Login required/, data[:error][:message]
    assert data['title'].nil?
    assert data['description'].empty?
  end

  test "sets external_id when it can be extracted from the URL" do
    parser = Parser::FacebookProfile.new('https://facebook.com/54421674438')
    data = parser.parse_data(meedan_doc, 'https://facebook.com/fake-inconsequential-url')
    assert_equal '54421674438', data['id']
    assert_equal '54421674438', data['external_id']

    parser = Parser::FacebookProfile.new('https://facebook.com/profile.php?id=54421674438')
    data = parser.parse_data(meedan_doc, 'https://facebook.com/fake-inconsequential-url')
    assert_equal '54421674438', data['id']
    assert_equal '54421674438', data['external_id']

    parser = Parser::FacebookProfile.new('https://facebook.com/people/fakeaccount/54421674438')
    data = parser.parse_data(meedan_doc,  'https://facebook.com/fake-inconsequential-url')
    assert_equal '54421674438', data['id']
    assert_equal '54421674438', data['external_id']

    parser = Parser::FacebookProfile.new('https://facebook.com/pages/fakeaccount/54421674438')
    data = parser.parse_data(meedan_doc,  'https://facebook.com/fake-inconsequential-url')
    assert_equal '54421674438', data['id']
    assert_equal '54421674438', data['external_id']
  end

  test "sets external_id when it can be extracted from the original URL, but not current URL" do
    parser = Parser::FacebookProfile.new('https://facebook.com/fakeaccount')
    data = parser.parse_data(meedan_doc, 'https://facebook.com/54421674438')
    assert_equal '54421674438', data['id']
    assert_equal '54421674438', data['external_id']
  end

  test "sets external_id from original url if current url is a login redirect" do
    parser = Parser::FacebookProfile.new('https://facebook.com/login.php?/id=12345')
    data = parser.parse_data(meedan_doc,'https://facebook.com/profile.php?id=54421674438')
    assert_equal '54421674438', data['id']
    assert_equal '54421674438', data['external_id']
  end

  test "sets external_id from HTML if URL matching does not work, but ID present in doc" do
    parser = Parser::FacebookProfile.new('https://facebook.com/fakeaccount')

    data = parser.parse_data(meedan_doc,'https://facebook.com/fakeaccount')
    assert_equal '54421674438', data['id']
    assert_equal '54421674438', data['external_id']

    data = parser.parse_data(arabic_doc, 'https://facebook.com/fakeaccount')
    assert_equal '179240385797', data['id']
    assert_equal '179240385797', data['external_id']
  end

  test "leaves external_id empty if ID cannot be found in URL or HTML" do
    parser = Parser::FacebookProfile.new('https://facebook.com/fakeaccount')
    data = parser.parse_data(login_doc, 'https://facebook.com/fakeaccount')

    assert data['external_id'].empty?
  end

  test "sets pictures from og:image metatag" do
    parser = Parser::FacebookProfile.new('https://facebook.com/fakeaccount')
    data = parser.parse_data(meedan_doc, throwaway_url)
    assert_match /scontent-lax3-1.xx.fbcdn.net\/v\/t39.30808-1\/310513247_435753678699138_2623398131510754475_n.png/, data['picture']
    assert_match /scontent-lax3-1.xx.fbcdn.net\/v\/t39.30808-1\/310513247_435753678699138_2623398131510754475_n.png/, data['author_picture']
  end

  test "leaves pictures blank when og:image metatag missing" do
    parser = Parser::FacebookProfile.new('https://facebook.com/fakeaccount')
    data = parser.parse_data(old_meedan_doc, throwaway_url)
    assert_nil data['picture']
    assert_nil data['author_picture']
  end

  test 'sets title from og:title tag if present' do
    parser = Parser::FacebookProfile.new('https://facebook.com/fakeaccount')
    data = parser.parse_data(arabic_doc, throwaway_url)

    assert_match /المركز الثقافي القبطي الأرثوذكسي بالمانيا/, data['title']
  end

  test 'sets title from title html tag if og:title not present' do
    parser = Parser::FacebookProfile.new('https://facebook.com/fakeaccount')
    data = parser.parse_data(old_meedan_doc, throwaway_url)

    assert_match /Meedan - Nonprofit Organization/, data['title']
  end

  test 'returns nil if og or html title tags not present' do
    parser = Parser::FacebookProfile.new('https://facebook.com/fakeaccount')
    data = parser.parse_data(empty_doc, throwaway_url)

    assert_nil data['title']
  end

  test "returns nil if title is a default, non-unique word" do
    parser = Parser::FacebookProfile.new('https://www.facebook.com/fakeaccount')

    doc = Nokogiri::HTML(<<~HTML)
      <meta property="og:title" content="Facebook" />
    HTML
    data = parser.parse_data(doc, 'https://facebook.com/fakeaccount')
    assert_nil data['title']

    doc = Nokogiri::HTML(<<~HTML)
      <title>Watch</title>
    HTML
    data = parser.parse_data(doc, 'https://facebook.com/fakeaccount')
    assert_nil data['title']
  end

  test "should strip '| Facebook' from page titles" do
    parser = Parser::FacebookProfile.new('https://www.facebook.com/fakeaccount')
    
    doc = Nokogiri::HTML(<<~HTML)
      <title>Piglet the Dog's post | Facebook</title>
    HTML
    data = parser.parse_data(doc, throwaway_url)
    assert_equal "Piglet the Dog's post", data['title']

    doc = Nokogiri::HTML(<<~HTML)
      <meta property="og:title" content="Piglet the Dog's post | Facebook" />
    HTML
    data = parser.parse_data(doc, throwaway_url)
    assert_equal "Piglet the Dog's post", data['title']
  end

  test 'sets description from og:description metatag if present' do
    parser = Parser::FacebookProfile.new('https://facebook.com/fakeaccount')
    data = parser.parse_data(meedan_doc, throwaway_url)

    assert_equal "Meedan. 3,783 likes · 65 were here. Make sense of the global web.", data['description']
  end

  test 'sets description from description metatag if og:description not present' do
    parser = Parser::FacebookProfile.new('https://facebook.com/fakeaccount')
    data = parser.parse_data(old_meedan_doc, throwaway_url)

    assert_equal "Meedan. 66 likes. Meedan is a non-profit social technology company which aims to increase cross-language interaction on the web, with particular emphasis...", data['description']
  end

  test 'leaves description empty if description not present in HTML present' do
    parser = Parser::FacebookProfile.new('https://facebook.com/fakeaccount')
    data = parser.parse_data(empty_doc, throwaway_url)

    assert_nil data['description']
  end

  test 'gets username from URL when possible' do
    parser = Parser::FacebookProfile.new('https://facebook.com/fakeaccount')
    data = parser.parse_data(meedan_doc, throwaway_url)
    assert_equal 'fakeaccount', data['username']

    parser = Parser::FacebookProfile.new('https://facebook.com/people/fakeaccount/123456789')
    data = parser.parse_data(meedan_doc, throwaway_url)
    assert_equal 'fakeaccount', data['username']

    parser = Parser::FacebookProfile.new('https://facebook.com/pages/fakeaccount/123456789')
    data = parser.parse_data(meedan_doc, throwaway_url)
    assert_equal 'fakeaccount', data['username']
  end

  test 'returns empty username if not clear from URL' do
    parser = Parser::FacebookProfile.new('https://facebook.com/events/123456')
    data = parser.parse_data(meedan_doc, throwaway_url)
    assert_nil data['username']

    parser = Parser::FacebookProfile.new('https://facebook.com/live/123456')
    data = parser.parse_data(meedan_doc, throwaway_url)
    assert_nil data['username']

    parser = Parser::FacebookProfile.new('https://facebook.com/livemap/123456')
    data = parser.parse_data(meedan_doc, throwaway_url)
    assert_nil data['username']

    parser = Parser::FacebookProfile.new('https://facebook.com/watch/123456')
    data = parser.parse_data(meedan_doc, throwaway_url)
    assert_nil data['username']

    parser = Parser::FacebookProfile.new('https://facebook.com/story.php/123456')
    data = parser.parse_data(meedan_doc, throwaway_url)
    assert_nil data['username']

    parser = Parser::FacebookProfile.new('https://facebook.com/category/123456')
    data = parser.parse_data(meedan_doc, throwaway_url)
    assert_nil data['username']

    parser = Parser::FacebookProfile.new('https://facebook.com/photo/123456')
    data = parser.parse_data(meedan_doc, throwaway_url)
    assert_nil data['username']

    parser = Parser::FacebookProfile.new('https://facebook.com/photo.php/123456')
    data = parser.parse_data(meedan_doc, throwaway_url)
    assert_nil data['username']

    # Note: we don't expect to realistically get this URL pattern in the parser because it would be
    # redirected to the human-readable link before we parse data
    parser = Parser::FacebookProfile.new('https://facebook.com/123456789')
    data = parser.parse_data(meedan_doc, throwaway_url)
    assert_nil data['username']
  end

  test 'sets author name from URL if possible' do
    parser = Parser::FacebookProfile.new('https://facebook.com/fakeaccount')
    data = parser.parse_data(meedan_doc, throwaway_url)
    assert_equal 'fakeaccount', data['author_name']

    parser = Parser::FacebookProfile.new('https://facebook.com/people/fakeaccount/123456789')
    data = parser.parse_data(meedan_doc, throwaway_url)
    assert_equal 'fakeaccount', data['author_name']

    parser = Parser::FacebookProfile.new('https://facebook.com/pages/fakeaccount/123456789')
    data = parser.parse_data(meedan_doc, throwaway_url)
    assert_equal 'fakeaccount', data['author_name']
  end

  test 'sets author name from og:title tag if not parseable from URL' do
    parser = Parser::FacebookProfile.new('https://facebook.com/1234567')
    data = parser.parse_data(arabic_doc, throwaway_url)

    assert_match /المركز الثقافي القبطي الأرثوذكسي بالمانيا/, data['author_name']
  end

  test 'sets author name from title html tag if if not parseable from URL and og:title not present' do
    parser = Parser::FacebookProfile.new('https://facebook.com/1234567')
    data = parser.parse_data(old_meedan_doc, throwaway_url)

    assert_equal 'Meedan - Nonprofit Organization', data['author_name']
  end

  test 'sets author_url to the passed url' do
    parser = Parser::FacebookProfile.new('https://facebook.com/fake-passed-url')
    data = parser.parse_data(meedan_doc, 'https://facebook.com/fake-original-url')

    assert_equal 'https://facebook.com/fake-passed-url', data['author_url']
  end

  test 'sets author_url to original url if passed url is forbidden' do
    parser = Parser::FacebookProfile.new('https://facebook.com/login/web')
    data = parser.parse_data(meedan_doc, 'https://facebook.com/fake-original-url')

    assert_equal 'https://facebook.com/fake-original-url', data['author_url']
  end

  test "#oembed_url returns URL with the instance URL" do
    oembed_url = Parser::FacebookProfile.new('https://www.facebook.com/fakeaccount').oembed_url
    assert_equal 'https://www.facebook.com/plugins/post/oembed.json/?url=https://www.facebook.com/fakeaccount', oembed_url
  end

  test "should store oembed data of a public facebook page" do
    url = 'https://facebook.com/513415662050479'
    canonical_url = 'https://www.facebook.com/heymeedan'
    picture_url = 'https://scontent-lax3-1.xx.fbcdn.net/v/t39.30808-1/310513247_435753678699138_2623398131510754475_n.png?_nc_cat=110&_nc_ht=scontent-lax3-1.xx&_nc_ohc=d6UgzKKHMJ8AX9tPN2o&_nc_sid=d36de4&ccb=1-7&oe=63DDB83C&oh=00_AfDH7lP98qp_etN0a2ZMms1tp6vx51198IAobPHbRLnSyA'
    
    WebMock.stub_request(:get, url).to_return(status: 200, body: meedan_doc.to_s)
    WebMock.stub_request(:get, canonical_url).to_return(status: 200)
    WebMock.stub_request(:get, "https://www.facebook.com/plugins/post/oembed.json/?url=#{canonical_url}").to_return(status: 200)
    WebMock.stub_request(:get, picture_url).to_return(status: 200)

    media = create_media url: url
    data = media.as_json

    assert data['oembed'].is_a?(Hash), "Expected #{data['oembed']} to be a Hash"
    assert_equal 'heymeedan', data['oembed']['author_name']
    assert_equal 'Meedan', data['oembed']['title']
  end
end
