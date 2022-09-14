require 'test_helper'

class FacebookItemIntegrationTest < ActiveSupport::TestCase
  test "should get facebook post with valid data from crowdtangle" do
    m = create_media url: 'https://www.facebook.com/144585402276277/posts/1127489833985824'
    data = m.as_json

    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
    assert_equal '144585402276277_1127489833985824', data['external_id']
    assert data['error'].blank?
    assert !data['title'].blank?
    assert !data['username'].blank?
    assert !data['author_name'].blank?
    assert !data['author_picture'].blank?
    assert !data['author_url'].blank?
    assert !data['description'].blank?
    assert !data['text'].blank?
    assert !data['picture'].blank?
    assert !data['subtype'].blank?
    assert !data['published_at'].blank?
  end

  test "should set title to URL and error if crowdtangle fails" do
    # This URL requires login to see
    m = create_media url: 'https://www.facebook.com/caiosba/posts/8457689347638947'
    data = m.as_json

    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
    assert_equal 'https://www.facebook.com/caiosba/posts/8457689347638947', data['title']
    assert !data['error'].blank?
  end

  # Previous integration tests
  test "should get canonical URL from facebook object 3" do
    url = 'https://www.facebook.com/54212446406/photos/a.397338611406/10157431603156407/?type=3&theater'
    media = Media.new(url: url)
    media.as_json({ force: 1 })
    assert_match 'https://www.facebook.com/54212446406/photos/a.397338611406/10157431603156407', media.url
  end

  test "should create Facebook post from mobile URL" do
    m = create_media url: 'https://m.facebook.com/KIKOLOUREIROofficial/photos/a.10150618138397252/10152555300292252/?type=3&theater'
    data = m.as_json
    assert !data['title'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
  end

  test "should not use Facebook embed if is a link to redirect" do
    url = 'https://l.facebook.com/l.php?u=https://hindi.indiatvnews.com/paisa/business-1-07-cr-new-taxpayers-added-dropped-filers-down-at-25-22-lakh-in-fy18-630914&h=AT1WAU-mDHKigOgFNrUsxsS2doGO0_F5W9Yck7oYUx-IsYAHx8JqyHwO02-N0pX8UOlcplZO50px8mkTA1XNyKig8Z2CfX6t3Sh0bHtO9MYPtWqacCm6gOXs5lbC6VGMLjDALNXZ6vg&s=1'

    m = create_media url: url
    data = m.as_json
    assert !data['title'].blank?
    assert_equal '', data['html']
  end

  test "should not change url when redirected to login page" do
    url = 'https://www.facebook.com/ugmhmyanmar/posts/2850282508516442'
    redirection_to_login_page = 'https://www.facebook.com/login/'
    response = 'mock'; response.stubs(:code).returns('302')
    response.stubs(:header).returns({ 'location' => redirection_to_login_page })
    response_login_page = 'mock'; response_login_page.stubs(:code).returns('200')
    RequestHelper.stubs(:request_url).with(url, 'Get').returns(response)
    RequestHelper.stubs(:request_url).with(redirection_to_login_page, 'Get').returns(response_login_page)
    RequestHelper.stubs(:request_url).with(redirection_to_login_page + '?next=https%3A%2F%2Fwww.facebook.com%2Fugmhmyanmar%2Fposts%2F2850282508516442', 'Get').returns(response_login_page)
    m = create_media url: url
    assert_equal url, m.url
  end

  test "should add login required error and return empty html and description" do
    html = "<title id='pageTitle'>Log in or sign up to view</title><meta property='og:description' content='See posts, photos and more on Facebook.'>"
    RequestHelper.stubs(:get_html).returns(Nokogiri::HTML(html))
    Media.any_instance.stubs(:follow_redirections)

    m = create_media url: 'https://www.facebook.com/caiosba/posts/3588207164560845'
    data = m.as_json
    assert_equal 'Login required to see this profile', data[:error][:message]
    assert_equal LapisConstants::ErrorCodes::const_get('LOGIN_REQUIRED'), data[:error][:code]
    assert_equal m.url, data[:title]
    assert data[:description].empty?
    assert data[:html].empty?
  end

  test "should get canonical URL parsed from facebook html when it is relative" do
    relative_url = '/dina.samak/posts/10153679232246949'
    url = "https://www.facebook.com#{relative_url}"
    RequestHelper.stubs(:get_html).returns(Nokogiri::HTML("<meta property='og:url' content='#{relative_url}'>"))
    Media.any_instance.stubs(:follow_redirections)
    m = create_media url: url
    assert_equal url, m.url
  end

  test "should get canonical URL parsed from facebook html when it is a page" do
    canonical_url = 'https://www.facebook.com/CyrineOfficialPage/posts/10154332542247479'
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML("<meta property='og:url' content='#{canonical_url}'>"))
    Media.any_instance.stubs(:follow_redirections)
    Media.stubs(:validate_url).with(canonical_url).returns(true)
    m = create_media url: 'https://www.facebook.com/CyrineOfficialPage/posts/10154332542247479?pnref=story.unseen-section'
    assert_equal canonical_url, m.url
  end

  test "should get the group name when parsing group post" do
    url = 'https://www.facebook.com/groups/memetics.hacking/permalink/1580570905320222/'
    m = Media.new url: url
    data = m.as_json
    assert_match "memetics.hacking", data['title']
    assert_match 'permalink/1580570905320222/', data['url']
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
  end

  test "should return empty html when FB url is private and cannot be embedded" do
    url = 'https://www.facebook.com/caiosba/posts/1913749825339929'
    m = create_media url: url
    data = m.as_json
    assert_equal 'facebook', data['provider']
    assert_equal '', data['html']
  end

  test "should store oembed data of a facebook post" do
    m = create_media url: 'https://www.facebook.com/144585402276277/posts/1127489833985824'
    m.as_json

    assert m.data['raw']['oembed'].is_a? Hash
    assert_match /facebook.com/, m.data['oembed']['provider_url']
    assert_equal "facebook", m.data['oembed']['provider_name'].downcase
  end
end

class FacebookItemUnitTest < ActiveSupport::TestCase
  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  def throwaway_url
    'http://facebook.com/throwaway-url'
  end

  def empty_doc
    @empty_doc ||= Nokogiri::HTML('')
  end
  
  def post_doc
    @post_doc ||= response_fixture_from_file('facebook-item-page_ironmaiden.html', parse_as: :html)
  end

  test "returns provider and type" do
    assert_equal Parser::FacebookItem.type, 'facebook_item'
  end

  test "matches known URL patterns, and returns instance on success" do
    assert_nil Parser::FacebookItem.match?('https://example.com')

    # Photo album post patterns
    assert Parser::FacebookItem.match?('https://www.facebook.com/54212446406/photos/a.397338611406/10157431603156407/?type=3&theater').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/Classic.mou/photos/1630270703817253').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/Classic.mou/photos/a.136991166478555/1494688604042131').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/Classic.mou/photos/pcb.613639338813733/613639175480416/').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/nostalgia.y/photos/a.508939832569501.1073741829.456182634511888/942167619246718/?type=3&theater').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/quoted.pictures/photos/a.128828073875334.28784.128791873878954/1096134023811396/?type=3&theater').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/ESCAPE.Egypt/photos/ms.c.eJxNk8d1QzEMBDvyQw79N2ZyaeD7osMIwAZKLGTUViod1qU~;DCBNHcpl8gfMKeR8bz2gH6ABlHRuuHYM6AdywPkEsH~;gqAjxqLAKJtQGZFxw7CzIa6zdF8j1EZJjXRgTzAP43XBa4HfFa1REA2nXugScCi3wN7FZpF5BPtaVDEBqwPNR60O9Lsi0nbDrw3KyaPCVZfqAYiWmZO13YwvSbtygCWeKleh9KEVajW8FfZz32qcUrNgA5wfkA4Xfh004x46d9gdckQt2xR74biSOegwIcoB9OW~_oVIxKML0JWYC0XHvDkdZy0oY5bgjvBAPwdBpRuKE7kZDNGtnTLoCObBYqJJ4Ky5FF1kfh75Gnyl~;Qxqsv.bps.a.1204090389632094.1073742218.423930480981426/1204094906298309/?type=3&theater').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/nostalgia.y/photos/pb.456182634511888.-2207520000.1484079948./928269767303170/?type=3&theater').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/teste637621352/photos/a.754851877912740.1073741826.749262715138323/896869113711015/?type=3').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/teste637621352/posts/1028795030518422').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/nanabhay/posts/10156130657385246?pnref=story').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/photo.php?fbid=10155150801660195&set=p.10155150801660195&type=1&theater').is_a?(Parser::FacebookItem)
    # Facebook live
    assert Parser::FacebookItem.match?('https://m.facebook.com/story.php?story_fbid=10154584426664820&id=355665009819%C2%ACif_t=live_video%C2%ACif_id=1476846578702256&ref=bookmarks').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/cbcnews/videos/10154783484119604/').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/teste637621352/posts/1538843716180215').is_a?(Parser::FacebookItem)
    # Facebook livemap
    assert Parser::FacebookItem.match?('https://www.facebook.com/livemap/#@-12.991858482361014,-38.521747589110994,4z').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/live/map/#@37.777053833008,-122.41587829590001,4z').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/live/discover/map/#@37.777053833008,-122.41587829590001,4z').is_a?(Parser::FacebookItem)
    # Event
    assert Parser::FacebookItem.match?('https://www.facebook.com/events/1090503577698748').is_a?(Parser::FacebookItem)
    # Video
    assert Parser::FacebookItem.match?('https://www.facebook.com/144585402276277/videos/1127489833985824').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/democrats/videos/10154268929856943').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/scmp/videos/10154584426664820').is_a?(Parser::FacebookItem)
    # Gif photo
    assert Parser::FacebookItem.match?('https://www.facebook.com/quoted.pictures/posts/1095740107184121').is_a?(Parser::FacebookItem)
    # Album post
    assert Parser::FacebookItem.match?('https://www.facebook.com/permalink.php?story_fbid=10154534111016407&id=54212446406').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/album.php?fbid=10154534110871407&id=54212446406&aid=1073742048').is_a?(Parser::FacebookItem)
    # User post
    assert Parser::FacebookItem.match?('https://www.facebook.com/dina.hawary/posts/10158416884740321').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/Classic.mou/posts/666508790193454:0').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/media/set?set=a.10154534110871407.1073742048.54212446406&type=3').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/pg/Mariano-Rajoy-Brey-54212446406/photos/?tab=album&album_id=10154534110871407').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/Bimbo.Memories/photos/pb.235404669918505.-2207520000.1481570271./1051597428299221/?type=3&theater').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/teste637621352/posts/1028795030518422').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/teste637621352/posts/1035783969819528').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/teste637621352/posts/2194142813983632').is_a?(Parser::FacebookItem)
    # Category
    assert Parser::FacebookItem.match?('https://www.facebook.com/pages/category/Society---Culture-Website/PoporDezamagit/photos/').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/groups/memetics.hacking/permalink/1580570905320222/').is_a?(Parser::FacebookItem)
  end

  test "returns empty title and description on crowdtangle failure, but populates embed html" do
    crowdtangle_error = response_fixture_from_file('crowdtangle-response_not-found.json')
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_error)

    data = Parser::FacebookItem.new('https://www.facebook.com/fakeaccount/posts/123456789').parse_data(empty_doc, 'https://www.facebook.com/fakeaccount/posts/new-123456789')

    assert_nil data['title']
    assert_nil data['description']
    assert_match /data-href="https:\/\/www.facebook.com\/fakeaccount\/posts\/123456789"/, data.dig('html')
  end
    
  test 'sets error when issue parsing UUID' do
    Parser::FacebookItem::IdsGrabber.any_instance.stubs(:uuid).returns(nil)

    data = Parser::FacebookItem.new('https://www.facebook.com/55555/posts/123456789').parse_data(empty_doc, throwaway_url)
    assert_match /No ID given for Crowdtangle/, data.dig('error', 'message')
  end
  
  test 'sets error when crowdtangle request fails' do
    crowdtangle_error = response_fixture_from_file('crowdtangle-response_not-found.json')
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_error)

    data = Parser::FacebookItem.new('https://www.facebook.com/55555/posts/123456789').parse_data(empty_doc, throwaway_url)

    assert_match /No results received from Crowdtangle/, data.dig('error', 'message')
  end

  test "sets information from crowdtangle" do
    crowdtangle_data = response_fixture_from_file('crowdtangle-response_video.json')
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_data)

    parser = Parser::FacebookItem.new('https://www.facebook.com/144585402276277/posts/1127489833985824')
    data = parser.parse_data(empty_doc, throwaway_url)

    assert_equal '144585402276277_1127489833985824', data['external_id']
    assert_equal 'Trent Aric - Meteorologist', data['author_name']
    assert_equal 'TrentAricTV', data['username']
    assert_match /273572839_489238069228086_8419777016738266396_n.jpg/, data['author_picture']
    assert_equal 'https://www.facebook.com/144585402276277', data['author_url']
    assert_match /Look at what the long range computer models are indicating/, data['title']
    assert_match /Look at what the long range computer models are indicating/, data['description']
    assert_match /Look at what the long range computer models are indicating/, data['text']
    assert_match /14602101_1127500960651378_1143375978446192640_n.jpg\?_nc_cat=107&ccb=1-6/, data['picture']
    assert_equal 'native_video', data['subtype']
    assert_equal '2016-10-05 11:15:30', data['published_at']
  end

  test "updates URL if different than received from crowdtangle" do
    crowdtangle_data = response_fixture_from_file('crowdtangle-response_video.json')
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_data)

    parser = Parser::FacebookItem.new('https://www.facebook.com/144585402276277/posts/1127489833985824')
    data = parser.parse_data(empty_doc, throwaway_url)

    assert_equal 'https://www.facebook.com/144585402276277/posts/1127489833985824/woo', parser.url
  end

  test 'when crowdtangle returns a different post than we tried to request' do
    crowdtangle_data = response_fixture_from_file('crowdtangle-response_video.json')
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_data)

    data = Parser::FacebookItem.new('https://www.facebook.com/12345/posts/55555').parse_data(empty_doc, 'https://www.facebook.com/12345/posts/55555')

    assert_match /Unexpected platform ID from Crowdtangle/, data.dig('error', 'message')
    assert_nil data['title']
    assert_nil data['description']
  end

  test "should return empty html for deleted posts (when doc cannot be returned)" do
    RequestHelper.stubs(:get_html).returns(nil)

    data = Parser::FacebookItem.new('https://www.facebook.com/fakeaccount/posts/12345').parse_data(nil, throwaway_url)
    assert_equal '', data[:html]
  end

  test "should return empty html when FB url is from group and cannot be embedded" do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: {}.to_json)

    data = Parser::FacebookItem.new('https://www.facebook.com/groups/976472102413753/permalink/2013383948722558/').parse_data(empty_doc, throwaway_url)

    assert_equal '', data['html']
  end
  
  test "should return empty html when FB url is event and cannot be embedded" do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: {}.to_json)

    data = Parser::FacebookItem.new('https://www.facebook.com/events/331430157280289').parse_data(empty_doc, throwaway_url)

    assert_equal '', data['html']
  end

  test "#oembed_url returns URL with the instance URL" do
    oembed_url = Parser::FacebookItem.new('https://www.facebook.com/fakeaccount/posts/1234').oembed_url
    assert_equal 'https://www.facebook.com/plugins/post/oembed.json/?url=https://www.facebook.com/fakeaccount/posts/1234', oembed_url
  end
end
