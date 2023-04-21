require 'test_helper'

class TiktokProfileIntegrationTest < ActiveSupport::TestCase
  test "should parse Tiktok profile for real" do
    m = create_media url: 'https://www.tiktok.com/@scout2015'
    data = m.as_json
    assert_equal '@scout2015', data['username']
    assert_equal 'profile', data['type']
    assert_equal 'tiktok', data['provider']
    assert !data['title'].blank?
    assert !data['author_name'].blank?
    assert_equal '@scout2015', data['external_id']
    assert_match 'https://www.tiktok.com/@scout2015', m.url
    assert_nil data['error']
  end
end

class TiktokProfileUnitTest < ActiveSupport::TestCase
  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  def doc
    @doc ||= response_fixture_from_file('tiktok-profile-page.html', parse_as: :html)
  end

  test "returns provider and type" do
    assert_equal Parser::TiktokProfile.type, 'tiktok_profile'
  end

  test "matches known URL patterns, and returns instance on success" do
    assert_nil Parser::TiktokProfile.match?('https://example.com')
    
    match_one = Parser::TiktokProfile.match?('https://www.tiktok.com/@fakeaccount')
    assert_equal true, match_one.is_a?(Parser::TiktokProfile)
  end
  
  test "assigns values to hash from the HTML doc" do
    data = Parser::TiktokProfile.new('https://www.tiktok.com/@fakeaccount').parse_data(doc)

    assert_equal '@fakeaccount', data['external_id']
    assert_equal '@fakeaccount', data['username']
    assert_match '@fakeaccount', data['title']
    assert_match '@fakeaccount', data['author_name']
    assert_match 'https://www.tiktok.com/@fakeaccount', data['description']
    assert_match 'https://www.tiktok.com/@fakeaccount', data['author_url']
    assert_match 'https://www.tiktok.com/@fakeaccount', data['url']
    assert_not_nil data['picture']
    assert_not_nil data['author_picture']
  end
  
  test "assigns values to hash from the json+ld" do
    jsonld = [{"@context"=>"https://schema.org/", "@type"=>"ItemList", "itemListElement"=>[]}, {"@context"=>"https://schema.org/", "@type"=>"BreadcrumbList", "itemListElement"=>[{"@type"=>"ListItem", "position"=>1, "item"=>{"@type"=>"Thing", "@id"=>"https://www.tiktok.com", "name"=>"TikTok"}}, {"@type"=>"ListItem", "position"=>2, "item"=>{"@type"=>"Thing", "@id"=>"https://www.tiktok.com/@huxleythepandapuppy", "name"=>"Huxley the Panda Puppy🐼🐶(pandaloon (@huxleythepandapuppy) | TikTok"}}]}, {"@context"=>"https://schema.org/", "@type"=>"Person", "name"=>"Huxley the Panda Puppy🐼🐶(pandaloon", "description"=>"CEO of Pandaloon from Shark Tank. Follow for ur dose of serotonin☺️My costumes⬇️", "alternateName"=>"huxleythepandapuppy", "url"=>"https://www.tiktok.com/@huxleythepandapuppy", "interactionStatistic"=>[{"@type"=>"InteractionCounter", "interactionType"=>{"@type"=>"http://schema.org/LikeAction"}, "userInteractionCount"=>110300000}, {"@type"=>"InteractionCounter", "interactionType"=>{"@type"=>"http://schema.org/FollowAction"}, "userInteractionCount"=>6200000}], "reviewedBy"=>{"@type"=>"Organization", "name"=>"TikTok", "url"=>"www.tiktok.com"}, "mainEntityOfPage"=>{"@id"=>"https://www.tiktok.com/@huxleythepandapuppy", "@type"=>"ProfilePage"}}]

    data = Parser::TiktokProfile.new('https://www.tiktok.com/@fakeaccount').parse_data(doc, 'https://www.tiktok.com/@fakeaccount', jsonld)

    assert_equal 'CEO of Pandaloon from Shark Tank. Follow for ur dose of serotonin☺️My costumes⬇️', data['description']
    assert_equal 'Huxley the Panda Puppy🐼🐶(pandaloon', data['title']
    assert_equal 'Huxley the Panda Puppy🐼🐶(pandaloon', data['author_name']
  end

  test "should set profile defaults upon error" do
    Parser::TiktokProfile.any_instance.stubs(:reparse_if_default_tiktok_page).raises(NoMethodError.new("Fake error raised for tests"))

    data = Parser::TiktokProfile.new('https://www.tiktok.com/@fakeaccount?is_from_webapp=1&sender_device=pc').parse_data(doc)

    assert_equal '@fakeaccount', data['external_id']
    assert_equal '@fakeaccount', data['username']
    assert_match '@fakeaccount', data['title']
    assert_match '@fakeaccount', data['author_name']
    assert_match 'https://www.tiktok.com/@fakeaccount', data['description']
  end

  test "should parse Tiktok profile with proxy if title is the site name" do
    blank_page = '<html><head><title>TikTok</title></head><body></body></html>'
    url = 'https://www.tiktok.com/@fakeaccount'

    header_options = RequestHelper.html_options(url)
    RequestHelper.stubs(:get_html).with(url, kind_of(Method), header_options, false).returns(Nokogiri::HTML(blank_page))
    RequestHelper.stubs(:get_html).with(url, kind_of(Method), header_options, true).returns(doc)
    
    parser = Parser::TiktokProfile.new(url)
    data = parser.parse_data(Nokogiri::HTML(blank_page))

    # Expect data from doc, not from blank_page
    # this is og:image from tiktok-profile-page.html
    assert_match /p16-sign-sg\.tiktokcdn\.com\/aweme\/720x720\/tos-alisg-avt-0068\/smg3daf0a613593be5f405fb8f34972f83f.jpeg/, data['picture']
  end

  test ".oembed_url returns oembed URL" do
    url = Parser::TiktokProfile.new('https://tiktok.com/fakeaccount').oembed_url
    assert_equal 'https://www.tiktok.com/oembed?url=https://tiktok.com/fakeaccount', url
  end
end
