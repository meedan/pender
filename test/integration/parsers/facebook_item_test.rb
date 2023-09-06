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

  # Previous integration tests


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

  test "should add login required error, return html and empty description" do
    html = "<title id='pageTitle'>Log in or sign up to view</title><meta property='og:description' content='See posts, photos and more on Facebook.'>"
    RequestHelper.stubs(:get_html).returns(Nokogiri::HTML(html))
    Media.any_instance.stubs(:follow_redirections)

    m = create_media url: 'https://www.facebook.com/caiosba/posts/3588207164560845'
    data = m.as_json
    
    assert_equal 'Login required to see this profile', data[:error][:message]
    assert_equal Lapis::ErrorCodes::const_get('LOGIN_REQUIRED'), data[:error][:code]
    assert_equal m.url, data[:title]
    assert data[:description].empty?
    assert_match "<div class=\"fb-post\" data-href=\"https://www.facebook.com/caiosba/posts/3588207164560845\"></div>", data['html']
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
    assert_match /(memetics.hacking|exploring belief systems)/, data['title']
    assert_match /permalink\/1580570905320222/, data['url']
    assert_equal 'facebook', data['provider']
    assert_equal 'item', data['type']
  end

  test "should return html even when FB url is private" do
    url = 'https://www.facebook.com/caiosba/posts/1913749825339929'
    m = create_media url: url
    data = m.as_json
    assert_equal 'facebook', data['provider']
    assert_match "<div class=\"fb-post\" data-href=\"https://www.facebook.com/caiosba/posts/1913749825339929\">", data['html']
  end

  test "should store oembed data of a facebook post" do
    m = create_media url: 'https://www.facebook.com/144585402276277/posts/1127489833985824'
    m.as_json

    assert m.data['raw']['oembed'].is_a? Hash
    assert_match /facebook.com/, m.data['oembed']['provider_url']
    assert_equal "facebook", m.data['oembed']['provider_name'].downcase
  end
end