require 'test_helper'

class FacebookItemIdsGrabberUnitTest < ActiveSupport::TestCase
  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  def throwaway_url
    'http://facebook.com/throwaway-url'
  end

  test "encodes passed URL on initialization and stores as parseable_url" do
    grabber = Parser::FacebookItem::IdsGrabber.new(nil, 'http://www.facebook.com/12 34', throwaway_url)

    assert_equal 'http://www.facebook.com/12%2034', grabber.parseable_uri.to_s
  end

  test "replaces moblie subdomain for www parseable_url" do
    grabber = Parser::FacebookItem::IdsGrabber.new(nil, 'http://m.facebook.com/1234', throwaway_url)

    assert_equal 'http://www.facebook.com/1234', grabber.parseable_uri.to_s
  end

  test "#post_id when can be parsed from request_url" do
    post_id = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/teste637621352/posts/2194142813983632', throwaway_url).post_id
    assert_equal '2194142813983632', post_id

    # Permalink - story_fbid
    post_id = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/permalink.php?story_fbid=10154534111016407&id=54212446406', throwaway_url).post_id
    assert_equal '10154534111016407', post_id

    # Photo - fbid
    post_id = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/photo.php?fbid=10155150801660195&set=p.10155150801660195&type=1&theater', throwaway_url).post_id
    assert_equal '10155150801660195', post_id

    # Story - story_fbid
    post_id = Parser::FacebookItem::IdsGrabber.new(nil, 'https://m.facebook.com/story.php?story_fbid=10154584426664820&id=355665009819%C2%ACif_t=live_video%C2%ACif_id=1476846578702256&ref=bookmarks', throwaway_url).post_id
    assert_equal '10154584426664820', post_id

    # Set - set
    post_id = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/media/set?set=a.10154534110871407.1073742048.54212446406&type=3', throwaway_url).post_id
    assert_equal '10154534110871407', post_id

    # Photos - album_id
    post_id = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/Mariano-Rajoy-Brey-54212446406/photos/?tab=album&album_id=10154534110871407', throwaway_url).post_id
    assert_equal '10154534110871407', post_id

    # Event - from URL
    post_id = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/events/1090503577698748', throwaway_url).post_id
    assert_equal '1090503577698748', post_id
  end

  test "#post_id strips :0 from post_id when present in URL" do
    post_id = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/Classic.mou/posts/666508790193454:0', throwaway_url).post_id
    assert_equal '666508790193454', post_id
  end

  test "#post_id falls back to using original_url to compute the post_id when request_url fails" do
    post_id = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/login/web', 'https://www.facebook.com/events/1090503577698748').post_id
    assert_equal '1090503577698748', post_id
  end

  test '#post_id when URL is of type that does not have an ID accessible (livemap, watch, etc)' do
    assert_nil Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/livemap/#@-12.991858482361014,-38.521747589110994,4z', throwaway_url).post_id
    assert_nil Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/live/map/#@37.777053833008,-122.41587829590001,4z', throwaway_url).post_id
    assert_nil Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/live/discover/map/#@37.777053833008,-122.41587829590001,4z', throwaway_url).post_id
    assert_nil Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/watch/1234567', throwaway_url).post_id
  end

  test '#post_id caches result once set' do
    grabber = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/teste637621352/posts/2194142813983632', throwaway_url)
    post_id = grabber.post_id
    assert_equal '2194142813983632', post_id

    Parser::FacebookItem.stub(:patterns, -> { raise "FacebookItem.patterns was called unexpectedly" }) do
      post_id = grabber.post_id
      assert_equal '2194142813983632', post_id
    end
  end

  test '#post_id returns album ID in URL params' do
    post_id = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/Mariano-Rajoy-Brey-54212446406/photos', 'https://www.facebook.com/pg/Mariano-Rajoy-Brey-54212446406/photos/?tab=album&album_id=10154534110871407').post_id
    assert_equal '10154534110871407', post_id
  end

  test '#post_id strips a. from relevant part of URL' do
    post_id = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/media/set?set=a.10154534110871407', throwaway_url).post_id
    assert_equal '10154534110871407', post_id
  end

  # USER_ID
  test '#user_id returns nil when passed event URL' do
    assert_nil Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/events/12345', throwaway_url).user_id
    assert_nil Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/login/web', 'https://www.facebook.com/events/12345').user_id
  end

  test '#user_id returns info from the HTML when present' do
    entity_id_doc = response_fixture_from_file('facebook-item-page_ironmaiden.html', parse_as: :html)
    user_id = Parser::FacebookItem::IdsGrabber.new(entity_id_doc, 'https://www.facebook.com/fakeaccount/posts/12345', throwaway_url).user_id
    assert_equal '100044470688234', user_id

    ios_id_doc = response_fixture_from_file('facebook-item-page_iosid.html', parse_as: :html)
    user_id = Parser::FacebookItem::IdsGrabber.new(ios_id_doc, 'https://www.facebook.com/fakeaccount/posts/12345', throwaway_url).user_id
    assert_equal '891167404572251', user_id
  end

  test '#user_id returns numeric ID query params from URL' do
    user_id = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/permalink.php?story_fbid=10154534111016407&id=54212446406', throwaway_url).user_id
    assert_equal '54212446406', user_id
  end

  test '#user_id returns secondary info from HTML if no ID in URL params' do
    # I'm not sure where these show up in the wild, so creating fake fixtures
    group_id_doc = Nokogiri::HTML('<script>{"groupID":"123456789","foo":"bar"}</script>')
    user_id = Parser::FacebookItem::IdsGrabber.new(group_id_doc, 'https://www.facebook.com/fakeaccount/posts/12345', throwaway_url).user_id
    assert_equal '123456789', user_id

    owner_doc = Nokogiri::HTML('<script>{"owner":{"__typename": "Page", "id": "179240385797", "__isVideoOwner": "Page"} }</script>')
    user_id = Parser::FacebookItem::IdsGrabber.new(owner_doc, 'https://www.facebook.com/fakeaccount/posts/12345', throwaway_url).user_id
    assert_equal '179240385797', user_id

    user_id_doc = Nokogiri::HTML('<script>{"userID":"123456789","foo":"bar"}</script>')
    user_id = Parser::FacebookItem::IdsGrabber.new(user_id_doc, 'https://www.facebook.com/fakeaccount/posts/12345', throwaway_url).user_id
    assert_equal '123456789', user_id
  end

  test '#user_id returns set ID from params as fallback' do
    user_id = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/media/set?set=a.10154534110871407.1073742048.54212446406&type=3', throwaway_url).user_id
    assert_equal '54212446406', user_id
  end

  test '#user_id returns set ID from original_url params as fallback' do
    skip 'implement fallback'
    user_id = Parser::FacebookItem::IdsGrabber.new(nil, throwaway_url, 'https://www.facebook.com/media/set?set=a.10154534110871407.1073742048.54212446406&type=3').user_id
    assert_equal '54212446406', user_id
  end

  test '#user_id returns numeric profile ID from request_url as fallback' do
    user_id = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/123456789/posts/55555555555', throwaway_url).user_id
    assert_equal '123456789', user_id
  end

  test '#user_id returns numeric profile ID from original_url as fallback' do
    user_id = Parser::FacebookItem::IdsGrabber.new(nil, throwaway_url, 'https://www.facebook.com/123456789/posts/55555555555').user_id
    assert_equal '123456789', user_id
  end

  test '#user_id caches result once set' do
    grabber = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/123456789/posts/2194142813983632', throwaway_url)
    user_id = grabber.user_id
    assert_equal '123456789', user_id

    Parser::FacebookItem.stub(:get_id_from_doc, -> { raise "FacebookItem.patterns was called unexpectedly" }) do
      user_id = grabber.user_id
      assert_equal '123456789', user_id
    end
  end

  test "#user_id grabs parses from photoset URL" do
    user_id = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/quoted.pictures/photos/a.128828073875334.28784.128791873878954/1096134023811396/?type=3&theater', throwaway_url).user_id
    assert_equal '128791873878954', user_id
  end

  test "#user_id should get owner id from info on script tag" do
    doc = Nokogiri::HTML('<script>{"data":{"__isMedia":"Photo","id":"861850457945558","owner":{"__typename":"Page","id":"456567378473870","__isProfile":"Page"}}}</script>')
    user_id = Parser::FacebookItem::IdsGrabber.new(doc, 'https://www.facebook.com/AsiNoPresidente/photos/a.457685231695418/861850457945558?type=3&theater', throwaway_url).user_id
    assert_equal '456567378473870', user_id
  end

  # UUID
  test '#uuid formats multi-part uuid' do
    uuid = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/media/set?set=a.10154534110871407.1073742048.54212446406&type=3', throwaway_url).uuid
    assert_equal '54212446406_10154534110871407', uuid

    uuid = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/quoted.pictures/photos/a.128828073875334.28784.128791873878954/1096134023811396/?type=3&theater', throwaway_url).uuid
    assert_equal '128791873878954_1096134023811396', uuid

    album_doc = response_fixture_from_file('facebook-item-page_photo-album.html', parse_as: :html)
    uuid = Parser::FacebookItem::IdsGrabber.new(album_doc, 'https://www.facebook.com/Mariano-Rajoy-Brey-54212446406/photos', 'https://www.facebook.com/pg/Mariano-Rajoy-Brey-54212446406/photos/?tab=album&album_id=10154534110871407').uuid
    assert_equal '54212446406_10154534110871407', uuid
  end

  test '#uuid returns nil when only one part of uuid can be found' do
    uuid = Parser::FacebookItem::IdsGrabber.new(nil, 'https://www.facebook.com/abcde/posts/1090503577698748', throwaway_url).uuid
    assert_nil uuid
  end
end
