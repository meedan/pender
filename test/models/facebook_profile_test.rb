require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class FacebookProfileTest < ActiveSupport::TestCase

  test "should parse Facebook page" do
    m = create_media url: 'https://www.facebook.com/ironmaiden/?fref=ts'
    data = m.as_json
    assert_match 'Iron Maiden', data['title']
    assert_match 'ironmaiden', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'profile', data['type']
    assert_nil data['error']
  end

  test "should parse Facebook page with numeric id" do
    m = create_media url: 'https://www.facebook.com/pages/Meedan/105510962816034?fref=ts'
    data = m.as_json
    assert !data['title'].blank?
    assert_match 'Meedan', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'page', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse Facebook with numeric id" do
    m = create_media url: 'http://facebook.com/513415662050479'
    data = m.as_json
    assert_match /facebook.com\/(NautilusMag|513415662050479)/, data['url']
    assert !data['title'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'profile', data['type']
  end

  test "should parse Arabic Facebook page" do
    m = create_media url: 'https://www.facebook.com/%D8%A7%D9%84%D9%85%D8%B1%D9%83%D8%B2-%D8%A7%D9%84%D8%AB%D9%82%D8%A7%D9%81%D9%8A-%D8%A7%D9%84%D9%82%D8%A8%D8%B7%D9%8A-%D8%A7%D9%84%D8%A3%D8%B1%D8%AB%D9%88%D8%B0%D9%83%D8%B3%D9%8A-%D8%A8%D8%A7%D9%84%D9%85%D8%A7%D9%86%D9%8A%D8%A7-179240385797/'
    data = m.as_json
    assert !data['title'].blank?
    assert_equal 'facebook', data['provider']
    assert_equal 'profile', data['type']
  end

  test "should parse Arabic URLs" do
    assert_nothing_raised do
      m = create_media url: 'https://www.facebook.com/إدارة-تموين-أبنوب-217188161807938/'
      data = m.as_json
    end
  end

  test "should get Facebook name when metatag is not present" do
    m = create_media url: 'https://www.facebook.com/ironmaiden/'
    doc = ''
    open('test/data/fb-page-without-og-title-metatag.html') { |f| doc = f.read }
    Media.any_instance.stubs(:get_facebook_profile_page).returns(Nokogiri::HTML(doc))

    data = m.as_json
    assert data['error'].nil?
    assert_equal 'Page without `og:title` defined', data['title']
    Media.any_instance.unstub(:get_facebook_profile_page)
  end

  test "should fallback to default Facebook title" do
    m = create_media url: 'https://ca.ios.ba/files/meedan/facebook.html'
    assert_equal 'Facebook', m.get_facebook_name
  end

  test "should have external id for profile" do
    m = create_media url: 'https://www.facebook.com/ironmaiden'
    data = m.as_json
    assert_not_nil data['external_id']
  end

  test "should add not found error and return empty html" do
    url = 'https://www.facebook.com/ldfkgjdfghodhg'

    m = create_media url: url
    data = m.as_json
    assert_equal '', data[:html]
    assert_equal LapisConstants::ErrorCodes::const_get('NOT_FOUND'), data[:error][:code]
    assert_equal 'URL Not Found', data[:error][:message]
  end

  test "should not get metrics from Facebook page" do
    Media.unstub(:request_metrics_from_facebook)
    Media.any_instance.stubs(:get_oembed_data)
    url = 'https://www.facebook.com/ironmaiden/'
    m = Media.new url: url
    data = m.as_json
    assert_equal({}, data['metrics']['facebook'], "Facebook metrics should be empty for pages")
    Media.any_instance.unstub(:get_oembed_data)
  end

  test "should parse FB user profile" do
    Media.any_instance.stubs(:follow_redirections)
    url = 'https://www.facebook.com/caiosba'
    html = '<span id="fb-timeline-cover-name" data-testid="profile_name_in_profile_page"><a href="https://www.facebook.com/caiosba">Caio Almeida <span>(Caiosba)</span></a></span>
           <div id="pagelet_bio" data-referrer="pagelet_bio">
             <div>
               <div><span>About Caio</span></div>
               <ul><li><div><div><span>Software Engineer</span></div></div></li></ul>
             </div>
           </div>
           <div class="profilePicThumb"><img src="https://example.com/image.jpg"></div>'
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML(html))
    m = Media.new url: url
    data = m.as_json
    assert_equal 'facebook', data['provider']
    assert_equal 'profile', data['type']
    assert_equal 'user', data['subtype']
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_html)
  end

  test "should parse Facebook not-legacy page" do
    Media.any_instance.stubs(:follow_redirections)
    html = '<head><meta name="description" content="Democratic Party. 1,653,325 likes · 73,028 talking about this. For more than 200 years, Democrats have represented the interests of working families,..."></head>
            <script>[{"__m":"PagesUsername.react"},{"name":"Democratic Party","pageID":"12301006942","username":"democrats","usernameEditDialogProfilePictureURI":"https:\/\/scontent-sea1-1.xx.fbcdn.net\/v\/t1.0-1\/cp0\/p60x60\/1526086_10152061389606943_5631354745317018857_n.png"}]</script>'
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML(html))

    m = create_media url: 'https://www.facebook.com/democrats/'
    data = m.as_json
    assert_match 'Democratic Party', data['title']
    assert_match 'democrats', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'profile', data['type']
    assert_nil data['error']
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_html)
  end

  test "should parse author name" do
    m = create_media url: 'https://www.facebook.com/75052548906'
    data = m.as_json
    assert_match 'Helloween', data['title']
    assert_match 'helloween', data['author_name'].downcase
    assert_match 'helloweenofficial', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'profile', data['type']
  end
end
