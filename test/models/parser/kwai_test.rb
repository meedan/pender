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
  end

  test "assigns values to hash from the HTML doc" do
    doc = response_fixture_from_file('kwai-page.html', parse_as: :html)

    data = Parser::KwaiItem.new('https://s.kw.ai/p/example').parse_data(doc)
    assert_equal "A special video", data[:title]
    assert_equal "A special video", data[:description]
    assert_equal 'Reginaldo Silva2871', data[:author_name]
    assert_equal 'Reginaldo Silva2871', data[:username]
  end

  test "assigns values to hash from the json+ld" do
    empty_doc = Nokogiri::HTML('')

    doc = Nokogiri::HTML(<<~HTML)
      <script data-n-head="ssr" type="application/ld+json" id="VideoObject">{"url":"https://www.kwai.com/@fakeuser/video/5221229445268222050","name":"Fake User. Áudio original criado por Fake User. ","description":"#tag1 #tag2 #tag3","transcript":"video transcript","thumbnailUrl":["http://ak-br-pic.kwai.net/kimg/fake_image_thumbnail.webp"],"uploadDate":"2023-05-22 01:41:04","contentUrl":"https://aws-br-cdn.kwai.net/upic/2023/05/22/01/fake_link.mp4?tag=1-1694439486-s-0-rnlkpacssc-56115f1493ef597d","commentCount":105,"duration":"PT1M7S","width":592,"height":1280,"audio":{"name":"Áudio original criado por Fake User","author":"Fake User","@type":"CreativeWork"},"creator":{"name":"Fake User","image":"https://aws-br-pic.kwai.net/bs2/overseaHead/fake_image.jpg","description":"Fake User Description","alternateName":"fakeuser","url":"https://www.kwai.com/@fakeuser","genre":["News","Politics & Economics"],"mainEntityOfPage":{"@id":"https://www.kwai.com/@fakeuser/video/5221229445268222050","@type":"ItemPage"},"@context":"https://schema.org/","@type":"VideoObject"}</script>
    HTML

    WebMock.stub_request(:any, 'https://www.kwai.com/@fakeuser/video/5221229445268222050').to_return(status: 200, body: doc.to_s)

    media = Media.new(url: 'https://www.kwai.com/@fakeuser/video/5221229445268222050')
    data = media.as_json

    assert_equal 'video transcript', data['description']
    assert_equal 'https://www.kwai.com/@fakeuser/video/5221229445268222050', data['title']
    assert_equal 'Fake User', data['author_name']
  end
end
