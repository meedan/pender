require 'test_helper'

class KwaiIntegrationTest < ActiveSupport::TestCase
  test "should parse Kwai URL" do
    m = create_media url: 'https://kwai-video.com/p/md02RsCS'
    data = m.as_json

    assert_equal 'Arthur Virgilio', data['username']
    assert_equal 'item', data['type']
    assert_equal 'kwai', data['provider']
    assert_equal 'Arthur Virgilio', data['author_name']
    assert_kind_of String, data['title']
    assert_kind_of String, data['description']
    assert_nil data['error']
  end
end

class KwaiUnitTest <  ActiveSupport::TestCase
  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  test "returns provider and type" do
    assert_equal Parser::KwaiItem.type, 'kwai_item'
  end

  test "matches known kwai URL patterns, and returns instance on success" do
    assert_nil Parser::KwaiItem.match?('https://example.com')
    
    match_one = Parser::KwaiItem.match?('https://s.kw.ai/p/1mCb9SSh')
    assert_equal true, match_one.is_a?(Parser::KwaiItem)
    match_two = Parser::KwaiItem.match?('https://m.kwai.com/photo/150000228494834/5222636779124848117')
    assert_equal true, match_two.is_a?(Parser::KwaiItem)
    match_three = Parser::KwaiItem.match?('https://kwai-video.com/p/6UCtAajG')
    assert_equal true, match_three.is_a?(Parser::KwaiItem)
    match_four = Parser::KwaiItem.match?('https://www.kwai.com/@AnonymouSScobar/video/5217288797260590112?page_source=guest_profile')
    assert_equal true, match_four.is_a?(Parser::KwaiItem)
  end
  
  test "does not match kwai profile URL" do
    match_five = Parser::PageItem.match?('https://www.kwai.com/@AnonymouSScobar')
    assert_equal false, match_five.is_a?(Parser::KwaiItem)
  end    

  test "assigns values to hash from the HTML doc" do
    doc = response_fixture_from_file('kwai-page.html', parse_as: :html)

    data = Parser::KwaiItem.new('https://s.kw.ai/p/example').parse_data(doc)
      assert_equal "A special video", data[:title]
      assert_equal "A special video", data[:description]
      assert_equal 'Reginaldo Silva2871', data[:author_name]
      assert_equal 'Reginaldo Silva2871', data[:username]
    end

  test "assigns description and username to hash from the json+ld" do
    empty_doc = Nokogiri::HTML('')
  
    jsonld = [{"url"=>"https://www.kwai.com/@fakeuser/video/5221229445268222050", "name"=>"Fake User. Áudio original criado por Fake User.", "description"=>"#tag1 #tag2 #tag3", "transcript"=>"video transcript ", "creator"=>{"name"=>"Fake User", "description"=>"Fake User Description", "alternateName"=>"fakeuser", "url"=>"https://www.kwai.com/@fakeuser"}, "@context"=>"https://schema.org/", "@type"=>"VideoObject"}]
  
    data = Parser::KwaiItem.new('https://www.kwai.com/fakelink').parse_data(empty_doc, 'https://www.kwai.com/fakelink', jsonld)
  
    assert_equal 'video transcript', data['description']
    assert_equal 'Fake User', data['author_name']
  end

  test "assigns values to hash from the json+ld and falls back to url as title" do
    doc = Nokogiri::HTML(<<~HTML)
      <script data-n-head="ssr" type="application/ld+json" id="VideoObject">{"url":"https://www.kwai.com/@fakeuser/111111111","name":"Fake User. Áudio original criado por Fake User. ","description":"#tag1 #tag2 #tag3","transcript":"video transcript","thumbnailUrl":["http://ak-br-pic.kwai.net/kimg/fake_thumbnail.webp"],"uploadDate":"2022-04-03 19:33:22","contentUrl":"https://cloudflare-br-cdn.kwai.net/upic/2022/04/03/19/fake_video.mp4?tag=1-1694090789-s-0-lm1vo6rkom-4c561f7187b6ac1b","commentCount":3568,"duration":"PT27S","width":612,"height":544,"audio":{"name":"Áudio original criado por Fake User","author":"Fake User","@type":"CreativeWork"},"creator":{"name":"Fake User","image":"https://aws-br-pic.kwai.net/bs2/overseaHead/fake_image.jpg","description":"criador de  conteúdo","alternateName":"fakeuser","url":"https://www.kwai.com/@fakeuser","interactionStatistic":[{"userInteractionCount":449001,"interactionType":{"@type":"http://schema.org/LikeAction"},"@type":"InteractionCounter"},{"userInteractionCount":33974,"interactionType":{"@type":"http://schema.org/FollowAction"},"@type":"InteractionCounter"}],"mainEntityOfPage":{"@id":"https://www.kwai.com/@wdklv443","@type":"ProfilePage"},"@type":"Person"},"interactionStatistic":[{"userInteractionCount":163968,"interactionType":{"@type":"http://schema.org/WatchAction"},"@type":"InteractionCounter"},{"userInteractionCount":10489,"interactionType":{"@type":"http://schema.org/LikeAction"},"@type":"InteractionCounter"},{"userInteractionCount":11899,"interactionType":{"@type":"http://schema.org/ShareAction"},"@type":"InteractionCounter"}],"mainEntityOfPage":{"@id":"https://www.kwai.com/@fakeuser/111111111","@type":"ItemPage"},"@context":"https://schema.org/","@type":"VideoObject"}</script>
    HTML

    WebMock.stub_request(:any, 'https://www.kwai.com/@fakeuser/111111111').to_return(status: 200, body: doc.to_s)

    media = Media.new(url: 'https://www.kwai.com/@fakeuser/111111111')
    data = media.as_json

    assert_equal 'video transcript', data['description']
    assert_equal 'https://www.kwai.com/@fakeuser/111111111', data['title']
    assert_equal 'Fake User', data['author_name']
  end

  test "fallbacks to the username on the url when doc and json+ld are not present, if name is present in the url" do
    empty_doc = Nokogiri::HTML('')

    data = Parser::KwaiItem.new('https://www.kwai.com/@fakeuser/111111111').parse_data(empty_doc, 'https://www.kwai.com/@fakeuser/111111111')

    assert_equal 'fakeuser', data['author_name']
  end
end
