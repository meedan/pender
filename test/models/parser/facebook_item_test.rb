require 'test_helper'

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

  def pfbid_doc
    @pfbid_doc ||= response_fixture_from_file('facebook-item-page_pfbid.html', parse_as: :html)
  end

  def crowdtangle_response
    <<~JSON
    {
      "status": 200,
      "result": {
        "posts": [
          {
            "platformId": "123456789276277_1127489833985824",
            "platform": "Facebook",
            "date": "2016-10-05 11:15:30",
            "updated": "2022-05-16 04:12:28",
            "type": "native_video",
            "message": "MATTHEW YOU ARE DRUNK...GO HOME! Look at what the long range computer models are indicating with Hurricane Matthew. Yes that's right the GFS model along with the ECMWF (European Model) are both showing Matthew looping around the Atlantic and heading back to the west toward Florida. Let's hope this trend changes and this DOES NOT HAPPEN. Let's get through the next 48hrs first...",
            "expandedLinks": [
              {
                "original": "https://www.facebook.com/TrentAricTV/videos/1127489833985824/",
                "expanded": "https://www.facebook.com/TrentAricTV/videos/1127489833985824/"
              }
            ],
            "link": "https://www.facebook.com/TrentAricTV/videos/1127489833985824/",
            "postUrl": "https://www.facebook.com/123456789276277/posts/1127489833985824/woo",
            "subscriberCount": 0,
            "score": 320.5113636363636,
            "media": [
              {
                "type": "video",
                "url": "https://video-sea1-1.xx.fbcdn.net/v/t42.1790-2/14611887_638161409698155_4235661386849452032_n.mp4?_nc_cat=109&ccb=1-6&_nc_sid=985c63&efg=eyJybHIiOjcyMywicmxhIjo1MTIsInZlbmNvZGVfdGFnIjoic3ZlX3NkIn0%3D&_nc_ohc=hOgMc6P8lbgAX_okTBW&rl=723&vabr=402&_nc_ht=video-sea1-1.xx&oh=00_AT8zx1iV-_tmlAkletndjbvSFjikw1j3yxZ4JNG33AJGRQ&oe=6283862F",
                "height": 0,
                "width": 0
              },
              {
                "type": "photo",
                "url": "https://scontent-sea1-1.xx.fbcdn.net/v/t15.5256-10/14602101_1127500960651378_1143375978446192640_n.jpg?stp=dst-jpg_s720x720&_nc_cat=107&ccb=1-6&_nc_sid=ad6a45&_nc_ohc=ElhPemC4khoAX-rBExM&_nc_ht=scontent-sea1-1.xx&oh=00_AT_O0XJgewEDqZ55eTyYX7kwt0CmlFX-Ikd-AvCVURY-qw&oe=6287A947",
                "height": 405,
                "width": 720,
                "full": "https://scontent-sea1-1.xx.fbcdn.net/v/t15.5256-10/14602101_1127500960651378_1143375978446192640_n.jpg?_nc_cat=107&ccb=1-6&_nc_sid=ad6a45&_nc_ohc=ElhPemC4khoAX-rBExM&_nc_ht=scontent-sea1-1.xx&oh=00_AT9zKVSCo0kkvuv2jEi4aJhSdyAU56Xcl0bEYU0lSQK19w&oe=6287A947"
              }
            ],
            "statistics": {
              "actual": {
                "likeCount": 2327,
                "shareCount": 18692,
                "commentCount": 5690,
                "loveCount": 18,
                "wowCount": 1110,
                "hahaCount": 100,
                "sadCount": 207,
                "angryCount": 61,
                "thankfulCount": 0,
                "careCount": 0
              },
              "expected": {
                "likeCount": 38,
                "shareCount": 4,
                "commentCount": 9,
                "loveCount": 12,
                "wowCount": 7,
                "hahaCount": 8,
                "sadCount": 7,
                "angryCount": 1,
                "thankfulCount": 0,
                "careCount": 2
              }
            },
            "account": {
              "id": 1612336,
              "name": "Trent Aric - Meteorologist",
              "handle": "TrentAricTV",
              "profileImage": "https://scontent-sea1-1.xx.fbcdn.net/v/t39.30808-1/273572839_489238069228086_8419777016738266396_n.jpg?stp=c184.151.769.769a_cp0_dst-jpg_s50x50&_nc_cat=106&ccb=1-7&_nc_sid=05dcb7&_nc_ohc=MV2d-ud_YnwAX_BySca&_nc_ht=scontent-sea1-1.xx&oh=00_AT9kUPnHwj5_OhDDe3BYUSjiDkz_RSV2dP_qn9frcqISkQ&oe=631CECF7",
              "subscriberCount": 10922,
              "url": "https://www.facebook.com/123456789276277",
              "platform": "Facebook",
              "platformId": "100044256918130",
              "accountType": "facebook_page",
              "pageAdminTopCountry": "US",
              "pageDescription": "Morning Meteorologist at WFTX Fox 4",
              "pageCreatedDate": "2011-04-18 14:08:05",
              "pageCategory": "NEWS_PERSONALITY",
              "verified": true
            },
            "videoLengthMS": 10967,
            "languageCode": "en",
            "legacyId": 0,
            "id": "1612336|1127489833985824"
          }
        ]
      }
    }
    JSON
  end

  def crowdtangle_response_not_found
    <<~JSON
      {"status":200,"notes":"Post not found"}
    JSON
  end

  test "returns provider and type" do
    assert_equal Parser::FacebookItem.type, 'facebook_item'
  end

  test "matches known URL patterns, and returns instance on success" do
    assert_nil Parser::FacebookItem.match?('https://example.com')

    # Photo album post patterns
    assert Parser::FacebookItem.match?('https://www.facebook.com/54212446406/photos/a.397338611406/10157431603156407/?type=3&theater').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/Classic.mou/photos/1630270703817253').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/Classic.mou/photos/pcb.613639338813733/613639175480416/').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/quoted.pictures/photos/a.128828073875334.28784.128791873878954/1096134023811396/?type=3&theater').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/ESCAPE.Egypt/photos/ms.c.eJxNk8d1QzEMBDvyQw79N2ZyaeD7osMIwAZKLGTUViod1qU~;DCBNHcpl8gfMKeR8bz2gH6ABlHRuuHYM6AdywPkEsH~;gqAjxqLAKJtQGZFxw7CzIa6zdF8j1EZJjXRgTzAP43XBa4HfFa1REA2nXugScCi3wN7FZpF5BPtaVDEBqwPNR60O9Lsi0nbDrw3KyaPCVZfqAYiWmZO13YwvSbtygCWeKleh9KEVajW8FfZz32qcUrNgA5wfkA4Xfh004x46d9gdckQt2xR74biSOegwIcoB9OW~_oVIxKML0JWYC0XHvDkdZy0oY5bgjvBAPwdBpRuKE7kZDNGtnTLoCObBYqJJ4Ky5FF1kfh75Gnyl~;Qxqsv.bps.a.1204090389632094.1073742218.423930480981426/1204094906298309/?type=3&theater').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/nostalgia.y/photos/pb.456182634511888.-2207520000.1484079948./928269767303170/?type=3&theater').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/photo.php?fbid=10155150801660195&set=p.10155150801660195&type=1&theater').is_a?(Parser::FacebookItem)
    # Facebook live
    assert Parser::FacebookItem.match?('https://m.facebook.com/story.php?story_fbid=10154584426664820&id=355665009819%C2%ACif_t=live_video%C2%ACif_id=1476846578702256&ref=bookmarks').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/54212446406/videos/10156131552571407').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/teste637621352/posts/1538843716180215').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/watch/live/?ref=live_delegate#@37.777053833008,-122.41587829590001,4z').is_a?(Parser::FacebookItem)
    # Event
    assert Parser::FacebookItem.match?('https://www.facebook.com/events/1090503577698748').is_a?(Parser::FacebookItem)
    # Gif photo
    assert Parser::FacebookItem.match?('https://www.facebook.com/quoted.pictures/posts/1095740107184121').is_a?(Parser::FacebookItem)
    # Album post
    assert Parser::FacebookItem.match?('https://www.facebook.com/permalink.php?story_fbid=10154534111016407&id=54212446406').is_a?(Parser::FacebookItem)
    # User post
    assert Parser::FacebookItem.match?('https://www.facebook.com/dina.hawary/posts/10158416884740321').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/Classic.mou/posts/666508790193454:0').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/media/set?set=a.10154534110871407.1073742048.54212446406&type=3').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/pg/Mariano-Rajoy-Brey-54212446406/photos/?tab=album&album_id=10154534110871407').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/Bimbo.Memories/photos/pb.235404669918505.-2207520000.1481570271./1051597428299221/?type=3&theater').is_a?(Parser::FacebookItem)
    # Category
    assert Parser::FacebookItem.match?('https://www.facebook.com/pages/category/Society---Culture-Website/PoporDezamagit/photos/').is_a?(Parser::FacebookItem)
    assert Parser::FacebookItem.match?('https://www.facebook.com/groups/memetics.hacking/permalink/1580570905320222/').is_a?(Parser::FacebookItem)
    # Story
    assert Parser::FacebookItem.match?('https://m.facebook.com/story.php?story_fbid=pfbid0213Dz5MyduLTHpELPoRmop9E7zj3Ed163P7djxSWbkfvaMSBrjNYTY9BFx6h7i3zWl&id=100054495283578').is_a?(Parser::FacebookItem)
  end

  test "sends tracing information to honeycomb, including updated URL" do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_response)

    TracingService.expects(:add_attributes_to_current_span).with({
      'app.parser.type' => 'facebook_item',
      'app.parser.parsed_url' => 'https://www.facebook.com/123456789276277/posts/1127489833985824/woo',
      'app.parser.original_url' => 'https://www.facebook.com/fakeaccount/posts/original-123456789'
    })

    Parser::FacebookItem.new('https://www.facebook.com/123456789276277/posts/1127489833985824').parse_data(empty_doc, 'https://www.facebook.com/fakeaccount/posts/original-123456789')
  end

  test "sets fallbacks from metatags on crowdtangle error, and populates HTML" do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_response_not_found)

    doc = Nokogiri::HTML(<<~HTML)
      <meta property="og:title" content="this is a page title" />
      <meta property="og:description" content="this is the page description" />
      <meta property="og:image" content="https://example.com/image" />
    HTML

    data = Parser::FacebookItem.new('https://www.facebook.com/fakeaccount/posts/123456789').parse_data(doc, 'https://www.facebook.com/fakeaccount/posts/new-123456789')

    assert data['error'].blank?
    assert !data['raw']['crowdtangle']['error'].blank?

    # Facebook sets the HTML title to the page title, and the post contents to description
    assert_equal 'this is the page description', data['title']
    assert_equal 'this is the page description', data['description']
    assert_equal 'https://example.com/image', data['picture']
    assert_match /data-href="https:\/\/www.facebook.com\/fakeaccount\/posts\/123456789"/, data.dig('html')
  end

  test "sets fallbacks from title metatags for event and watch URLS on crowdtangle error, and populates HTML" do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_response_not_found)

    doc = Nokogiri::HTML(<<~HTML)
      <meta property="og:title" content="this is a page title | Facebook" />
      <meta property="og:description" content="this is the page description" />
      <meta property="og:image" content="https://example.com/image" />
      <title id='pageTitle'>this is also a page title | Facebook</title>
    HTML

    data = Parser::FacebookItem.new('https://www.facebook.com/events/331430157280289').parse_data(doc, throwaway_url)
    assert_equal 'this is a page title', data['title']
    assert_equal 'this is the page description', data['description']

    data = Parser::FacebookItem.new('https://www.facebook.com/watch/live/?ref=live_delegate#@37.777053833008,-122.41587829590001,4z').parse_data(doc, throwaway_url)
    assert_equal 'this is a page title', data['title']
    assert_equal 'this is the page description', data['description']

    data = Parser::FacebookItem.new('https://www.facebook.com/K9Ballistics/videos/upgrade-your-dog-bed/1871564813213101/').parse_data(doc, throwaway_url)
    assert_equal 'this is a page title', data['title']
    assert_equal 'this is the page description', data['description']
  end

  # Implicitly testing MediaCrowdtangleItem
  test "sends error to sentry when we receive unexpected response from crowdtangle API" do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: '')

    data = {}
    sentry_call_count = 0
    arguments_checker = Proc.new do |e|
      sentry_call_count += 1
      assert_equal MediaCrowdtangleItem::CrowdtangleError, e.class
    end
    PenderSentry.stub(:notify, arguments_checker) do
      data = Parser::FacebookItem.new('https://www.facebook.com/555555/posts/123456789').parse_data(empty_doc, throwaway_url)
    end
    assert_equal 1, sentry_call_count
  end

  test 'sets raw error when issue parsing UUID' do
    Parser::FacebookItem::IdsGrabber.any_instance.stubs(:uuid).returns(nil)

    data = Parser::FacebookItem.new('https://www.facebook.com/55555/posts/123456789').parse_data(empty_doc, throwaway_url)
    assert data['error'].blank?
    assert_match /No ID given for Crowdtangle/, data.dig('raw', 'crowdtangle', 'error', 'message')
  end

  test 'sets raw error when crowdtangle request fails' do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_response_not_found)
    data = Parser::FacebookItem.new('https://www.facebook.com/55555/posts/123456789').parse_data(empty_doc, throwaway_url)

    assert data['error'].blank?
    assert_match /No results received from Crowdtangle/, data.dig('raw', 'crowdtangle', 'error', 'message')
  end

  test "sets information from crowdtangle" do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_response)

    parser = Parser::FacebookItem.new('https://www.facebook.com/123456789276277/posts/1127489833985824')
    data = parser.parse_data(empty_doc, throwaway_url)

    assert data['error'].blank?
    assert_equal '123456789276277_1127489833985824', data['external_id']
    assert_equal 'Trent Aric - Meteorologist', data['author_name']
    assert_equal 'TrentAricTV', data['username']
    assert_match /273572839_489238069228086_8419777016738266396_n.jpg/, data['author_picture']
    assert_equal 'https://www.facebook.com/123456789276277', data['author_url']
    assert_match /Look at what the long range computer models are indicating/, data['title']
    assert_match /Look at what the long range computer models are indicating/, data['description']
    assert_match /Look at what the long range computer models are indicating/, data['text']
    assert_match /14602101_1127500960651378_1143375978446192640_n.jpg\?_nc_cat=107&ccb=1-6/, data['picture']
    assert_equal 'native_video', data['subtype']
    assert_equal '2016-10-05 11:15:30', data['published_at']
  end

  test "updates URL if different than received from crowdtangle" do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_response)

    parser = Parser::FacebookItem.new('https://www.facebook.com/123456789276277/posts/1127489833985824')
    data = parser.parse_data(empty_doc, throwaway_url)

    assert_equal 'https://www.facebook.com/123456789276277/posts/1127489833985824/woo', parser.url
  end

  test 'when crowdtangle returns a different post than we tried to request' do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_response)

    data = Parser::FacebookItem.new('https://www.facebook.com/12345/posts/55555').parse_data(empty_doc, 'https://www.facebook.com/12345/posts/55555')

    assert data['error'].blank?
    assert_match /Unexpected platform ID from Crowdtangle/, data.dig('raw', 'crowdtangle', 'error', 'message')
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

    data = Parser::FacebookItem.new('https://www.facebook.com/groups/133819471984630/').parse_data(empty_doc, throwaway_url)

    assert_equal '', data['html']
  end

  test "should return empty html when FB url is event and cannot be embedded" do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: {}.to_json)

    data = Parser::FacebookItem.new('https://www.facebook.com/events/331430157280289').parse_data(empty_doc, throwaway_url)

    assert_equal '', data['html']
  end

  test "should reject default page titles" do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: {}.to_json)
    parser = Parser::FacebookItem.new('https://www.facebook.com/fakeaccount/posts/12345')

    doc = Nokogiri::HTML(<<~HTML)
      <meta property="og:title" content="Facebook" />
    HTML
    data = parser.parse_data(doc, throwaway_url)
    assert_nil data['title']

    doc = Nokogiri::HTML(<<~HTML)
    <title>Watch</title>
    HTML
    data = parser.parse_data(doc, throwaway_url)
    assert_nil data['title']
  end

  test "sets unique title from page description when FB post ID is obscured in URL" do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: {}.to_json)

    parser = Parser::FacebookItem.new('https://www.facebook.com/LittleMix/posts/pfbid0E7xrT6BDrv7r7Ry3kHUSdw2naE6BdFBgH2gTsEY9h1a64DdM3vqPyq8gXaFY5rqhl')
    data = parser.parse_data(pfbid_doc, throwaway_url)

    assert_match /Nothing comes between us/, data['title']
  end

  test "#oembed_url returns URL with the instance URL" do
    oembed_url = Parser::FacebookItem.new('https://www.facebook.com/fakeaccount/posts/1234').oembed_url
    assert_equal 'https://www.facebook.com/plugins/post/oembed.json/?url=https://www.facebook.com/fakeaccount/posts/1234', oembed_url
  end

  test "should return default data (set title to URL and description to empty string) when redirected to login page" do
    url = 'https://m.facebook.com/groups/593719938050039/permalink/1184073722347988'
    
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_response_not_found)

    doc = Nokogiri::HTML(<<~HTML)
      <meta property="og:title" content="Log into Facebook | Facebook" />
      <meta property="og:description" content="Log into Facebook to start sharing and connecting with your friends, family, and people you know." />
    HTML

    WebMock.stub_request(:any, url).to_return(status: 200, body: doc.to_s)

    media = Media.new(url: url)
    data = media.as_json

    assert_equal url, data['title']
    assert_match '', data['description']
  end

  test "should get canonical URL from facebook object 3" do
    url_from_facebook_object_3 = 'https://www.facebook.com/54212446406/photos/a.397338611406/10157431603156407/?type=3&theater'
    canonical_url = "https://www.facebook.com/54212446406/photos/a.397338611406/10157431603156407"

    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_response)

    doc = Nokogiri::HTML(<<~HTML)
      <meta property="og:url" content="https://www.facebook.com/54212446406/photos/a.397338611406/10157431603156407" />
    HTML

    WebMock.stub_request(:any, url_from_facebook_object_3).to_return(status: 200, body: doc.to_s)
    WebMock.stub_request(:any, canonical_url).to_return(status: 200)
    WebMock.stub_request(:get, "https://www.facebook.com/plugins/post/oembed.json/?url=#{canonical_url}").to_return(status: 200)

    media = Media.new(url: url_from_facebook_object_3)
    data = media.as_json

    assert_match canonical_url, data['url']
  end

  test "should create Facebook post from mobile URL" do
    url = 'https://m.facebook.com/KIKOLOUREIROofficial/photos/a.10150618138397252/10152555300292252/?type=3&theater'

    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_response)

    WebMock.stub_request(:any, url).to_return(status: 200)
    WebMock.stub_request(:get, "https://www.facebook.com/plugins/post/oembed.json/?theater&url=https://m.facebook.com/KIKOLOUREIROofficial/photos/a.10150618138397252/10152555300292252?type=3").to_return(status: 200)

    media = Media.new(url: url)
    data = media.as_json

    assert !data['title'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
  end

  test "should not use Facebook embed if is a link to redirect" do
    # not sure about keeping this test, it has a few issues: 1. it's hiting profile not item 2. this link doesn't redirect from FB to a different site, it hits a 'post doesn't exist' sort of message 3. I tried looking for a post that did re-redirect but I think that behavior might no longer exist
    # I'll leave this here for now and come back to it to decide what to do with this
    url = 'https://l.facebook.com/l.php?u=https://hindi.indiatvnews.com/paisa/business-1-07-cr-new-taxpayers-added-dropped-filers-down-at-25-22-lakh-in-fy18-630914&h=AT1WAU-mDHKigOgFNrUsxsS2doGO0_F5W9Yck7oYUx-IsYAHx8JqyHwO02-N0pX8UOlcplZO50px8mkTA1XNyKig8Z2CfX6t3Sh0bHtO9MYPtWqacCm6gOXs5lbC6VGMLjDALNXZ6vg&s=1'
    
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_response_not_found)

    doc = Nokogiri::HTML(<<~HTML)
      <meta property="og:title" content="some page title" />
      <meta property="og:description" content="this is the page description" />
      <title id="pageTitle">this is also a page title</title>
    HTML

    WebMock.stub_request(:any, url).to_return(status: 200, body: doc.to_s)
    WebMock.stub_request(:get, "https://www.facebook.com/plugins/post/oembed.json/?url=#{url}").to_return(status: 200)

    media = Media.new(url: url)
    data = media.as_json

    assert !data['title'].blank?
    assert_equal '', data['html']
  end

  test "should return canonical url when redirected to login page" do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_response_not_found)

    url = 'https://www.facebook.com/ugmhmyanmar/posts/2850282508516442'
    canonical_url = 'https://www.facebook.com/ugmhmyanmar/posts/ugmh-%E1%80%80%E1%80%95%E1%80%BC%E1%80%B1%E1%80%AC%E1%80%90%E1%80%B2%E1%80%B7-ugmh-%E1%80%A1%E1%80%80%E1%80%BC%E1%80%B1%E1%80%AC%E1%80%84%E1%80%BA%E1%80%B8%E1%80%A1%E1%80%95%E1%80%AD%E1%80%AF%E1%80%84%E1%80%BA%E1%80%B8-%E1%81%84%E1%80%80%E1%80%90%E1%80%AD%E1%80%99%E1%80%90%E1%80%8A%E1%80%BA%E1%80%81%E1%80%BC%E1%80%84%E1%80%BA%E1%80%B8-%E1%80%80%E1%80%9C%E1%80%AD%E1%80%94%E1%80%BA%E1%80%80%E1%80%BB%E1%80%85%E1%80%BA%E1%80%80%E1%80%BB%E1%80%81%E1%80%BC%E1%80%84%E1%80%BA%E1%80%B8%E1%80%9B%E1%80%B2%E1%80%B7-%E1%80%A1%E1%80%80%E1%80%BB%E1%80%AD%E1%80%AF%E1%80%B8%E1%80%86%E1%80%80%E1%80%BA%E1%80%9F%E1%80%AC/2850282508516442/'
    redirection_to_login_page = 'https://www.facebook.com/login/'
    
    doc = Nokogiri::HTML(<<~HTML)
      <meta property="og:url" content="#{canonical_url}"/>
    HTML
    
    response = 'mock'; response.stubs(:code).returns('302')
    response.stubs(:header).returns({ 'location' => redirection_to_login_page })
    response_login_page = 'mock'; response_login_page.stubs(:code).returns('200')
    
    RequestHelper.stubs(:request_url).with(url, 'Get').returns(response)
    RequestHelper.stubs(:request_url).with(canonical_url, 'Get').returns(response)
    RequestHelper.stubs(:request_url).with(redirection_to_login_page, 'Get').returns(response_login_page)
    RequestHelper.stubs(:request_url).with(redirection_to_login_page + '?next=https%3A%2F%2Fwww.facebook.com%2Fugmhmyanmar%2Fposts%2F2850282508516442', 'Get').returns(response_login_page)

    WebMock.stub_request(:get, url).to_return(status: 200, body: doc.to_s)
    
    media = Media.new(url: url)

    assert_equal canonical_url, media.url 
    assert_equal url, media.original_url 
  end

  test "should add login required error, return html and empty description" do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_response_not_found)

    url = 'https://www.facebook.com/caiosba/posts/3588207164560845'

    html = "<title id='pageTitle'>Log in or sign up to view</title><meta property='og:description' content='See posts, photos and more on Facebook.'>"
    RequestHelper.stubs(:get_html).returns(Nokogiri::HTML(html))
    Media.any_instance.stubs(:follow_redirections)

    WebMock.stub_request(:get, url).to_return(status: 200)

    m = Media.new(url: url)
    data = m.as_json
    
    assert_equal 'Login required to see this profile', data[:error][:message]
    assert_equal Lapis::ErrorCodes::const_get('LOGIN_REQUIRED'), data[:error][:code]
    assert_equal m.url, data[:title]
    assert data[:description].empty?
    assert_match "<div class=\"fb-post\" data-href=\"#{url}\"></div>", data['html']
  end

  test "should get canonical URL parsed from facebook html when it is relative" do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_response)

    relative_url = '/dina.samak/posts/10153679232246949'
    url = "https://www.facebook.com#{relative_url}"

    RequestHelper.stubs(:get_html).returns(Nokogiri::HTML("<meta property='og:url' content='#{relative_url}'>"))
    Media.any_instance.stubs(:follow_redirections)

    WebMock.stub_request(:get, url).to_return(status: 200)

    m = Media.new(url: url)
    assert_equal url, m.url
  end

  test "should get canonical URL parsed from facebook html when it is a page" do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_response)

    canonical_url = 'https://www.facebook.com/CyrineOfficialPage/posts/10154332542247479'
    url = 'https://www.facebook.com/CyrineOfficialPage/posts/10154332542247479?pnref=story.unseen-section'

    doc = Nokogiri::HTML(<<~HTML)
      <meta property='og:url' content="#{canonical_url}">
    HTML

    WebMock.stub_request(:get, url).to_return(status: 200, body: doc.to_s)
    WebMock.stub_request(:get, canonical_url).to_return(status: 200)

    m = Media.new(url: url)
    assert_equal canonical_url, m.url
  end

  test "should get the group name when parsing group post" do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_response)

    url = 'https://www.facebook.com/groups/memetics.hacking/permalink/1580570905320222'

    doc = Nokogiri::HTML(<<~HTML)
      <meta property="og:title" content="Welcome! This group is a gathering for those interested in exploring belief systems" />
    HTML

    WebMock.stub_request(:get, url).to_return(status: 200, body: doc.to_s)
    WebMock.stub_request(:get, "https://www.facebook.com/plugins/post/oembed.json/?url=#{url}").to_return(status: 200)

    m = Media.new(url: url)
    data = m.as_json

    assert_match /(memetics.hacking|exploring belief systems)/, data['title']
    assert_match /permalink\/1580570905320222/, data['url']
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
  end

  test "should return html even when FB url is private" do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_response_not_found)

    url = 'https://www.facebook.com/caiosba/posts/1913749825339929'

    html = "<title id='pageTitle'>Log in or sign up to view</title><meta property='og:description' content='See posts, photos and more on Facebook.'>"
    RequestHelper.stubs(:get_html).returns(Nokogiri::HTML(html))

    WebMock.stub_request(:get, url).to_return(status: 200)

    m = Media.new(url: url)
    data = m.as_json
    
    assert_equal 'facebook', data['provider']
    assert_match "<div class=\"fb-post\" data-href=\"https://www.facebook.com/caiosba/posts/1913749825339929\">", data['html']
  end

  test "should store oembed data of a facebook post" do
    WebMock.stub_request(:any, /api.crowdtangle.com\/post/).to_return(status: 200, body: crowdtangle_response)

    url = 'https://www.facebook.com/144585402276277/posts/1127489833985824'

    WebMock.stub_request(:get, url).to_return(status: 200, body: empty_doc.to_s)
    WebMock.stub_request(:get, "https://www.facebook.com/plugins/post/oembed.json/?url=#{url}").to_return(status: 200)
    
    m = Media.new(url: url)
    data = m.as_json

    assert data['oembed'].is_a? Hash
    assert_match /facebook.com/, data['oembed']['provider_url']
    assert_equal "facebook", data['oembed']['provider_name'].downcase
  end
end
