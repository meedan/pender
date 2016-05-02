require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class MediaTest < ActiveSupport::TestCase
  test "should create media" do
    assert_kind_of Media, create_media
  end

  test "should have URL" do
    m = create_media url: 'http://foo.bar'
    assert_equal 'http://foo.bar', m.url
  end

  test "should parse YouTube user" do
    m = create_media url: 'https://www.youtube.com/user/portadosfundos'
    data = m.as_json
    assert_equal 'Porta dos Fundos', data['title']
    assert_equal 'portadosfundos', data['username']
    assert_equal 'user', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse YouTube channel" do
    m = create_media url: 'https://www.youtube.com/channel/UCQDZiehIRKS6o9AlX1g8lSw'
    data = m.as_json
    assert_equal 'Documentarios em Portugues', data['title']
    assert_equal 'DocumentariosemPortugues', data['username']
    assert_equal 'channel', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should not cache result" do
    Media.any_instance.stubs(:parse).once
    create_media url: 'https://www.youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQ'
  end

  test "should cache result" do
    create_media url: 'https://www.youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQ'
    Media.any_instance.stubs(:parse).never
    create_media url: 'https://www.youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQ'
  end

  test "should parse Twitter profile" do
    m = create_media url: 'https://twitter.com/caiosba'
    data = m.as_json
    assert_equal 'Caio Almeida', data['title']
    assert_equal 'caiosba', data['username']
    assert_equal 'twitter', data['provider']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
    assert_kind_of Hash, data['pictures']
  end

  test "should parse Facebook user profile with identifier" do
    m = create_media url: 'https://www.facebook.com/akitaonrails'
    data = m.as_json
    assert_equal 'Fabio Akita', data['title']
    assert_equal 'akitaonrails', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'user', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse Facebook user profile with numeric id" do
    m = create_media url: 'https://www.facebook.com/profile.php?id=100008161175765&fref=ts'
    data = m.as_json
    assert_equal 'Tico Santa Cruz', data['title']
    assert_equal 'Tico-Santa-Cruz', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'user', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse Facebook page" do
    m = create_media url: 'https://www.facebook.com/ironmaiden/?fref=ts'
    data = m.as_json
    assert_equal 'Iron Maiden', data['title']
    assert_equal 'ironmaiden', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'page', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse Facebook page with numeric id" do
    m = create_media url: 'https://www.facebook.com/pages/Meedan/105510962816034?fref=ts'
    data = m.as_json
    assert_equal 'Meedan', data['title']
    assert_equal 'Meedan', data['username']
    assert_equal 'facebook', data['provider']
    assert_equal 'page', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should return item as oembed" do
    url = 'https://www.facebook.com/pages/Meedan/105510962816034?fref=ts'
    m = create_media url: url
    data = m.as_oembed("http://pender.org/medias.html?url=#{url}", 300, 150)
    assert_equal 'Meedan', data['title']
    assert_equal 'Meedan', data['author_name']
    assert_equal url, data['author_url']
    assert_equal 'facebook', data['provider_name']
    assert_equal 'http://www.facebook.com', data['provider_url']
    assert_equal 300, data['width']
    assert_equal 150, data['height']
    assert_equal '<iframe src="http://pender.org/medias.html?url=https://www.facebook.com/pages/Meedan/105510962816034?fref=ts" width="300" height="150" scrolling="no" border="0" seamless>Not supported</iframe>', data['html']
    assert_not_nil data['thumbnail_url']
  end

  test "should parse Checkdesk report" do
    m = create_media url: 'https://meedan.checkdesk.org/node/2161'
    data = m.as_json
    assert_equal 'Twitter / History In Pictures: Little Girl &amp; Ba...', data['title']
    assert_equal 'Tom', data['username']
    assert_equal 'oembed', data['provider']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse Facebook with numeric id" do
    m = create_media url: 'http://facebook.com/513415662050479'
    data = m.as_json
    assert_equal 'https://www.facebook.com/NautilusMag/', data['url']
    assert_equal 'Nautilus Magazine', data['title']
  end

  test "should parse YouTube user with slash" do
    m = create_media url: 'https://www.youtube.com/user/portadosfundos/'
    data = m.as_json
    assert_equal 'Porta dos Fundos', data['title']
    assert_equal 'portadosfundos', data['username']
    assert_equal 'user', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse YouTube channel with slash" do
    m = create_media url: 'https://www.youtube.com/channel/UCQDZiehIRKS6o9AlX1g8lSw/'
    data = m.as_json
    assert_equal 'Documentarios em Portugues', data['title']
    assert_equal 'DocumentariosemPortugues', data['username']
    assert_equal 'channel', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should get likes for Facebook profile" do
    # Token for v2.5 API
    stub_configs({ facebook_api_version: 'v2.5', facebook_auth_token: 'CAAIwqnm9a9cBAMQyV3UeawV9vfnrT0DgGKYrDJ72gzoCBZArHZCvsVZBZCJvl8NgrQZAWgFlGLbXWsbw1gZAPvAn2zSJjvwRBSz1yykrAhgNM1m89WJfG5Sw3behKArplgBws6ZC3Arx2eNZAAcGv2HowPd3ZCIycmNx9mjFiSdpSwKudPKmJZARx1aH6e35gO49kZD' })
    m = create_media url: 'https://www.facebook.com/ironmaiden/?fref=ts'
    data = m.as_json
    likes = data['likes']
    assert_match /^[0-9]+$/, data['likes'].to_s

    Rails.cache.clear

    # Token for v2.6 API
    stub_configs({ facebook_api_version: 'v2.6', facebook_auth_token: 'EAAW42ANfhLIBAA7VsZBA9n763j9oMYQ0fqdFA14QdFUdiot2ZBTAkkFZA3eydNdL14A7fjeOyhHJC8v0NQjQwxw9P4zvR86SE3KDjxns9ZAXNHsynjGme6gN0ZC02nZBZCk5dvTtOkvbulRjDvfsxqcyK3C7RvZAjeIZD' })
    m = create_media url: 'https://www.facebook.com/ironmaiden/?fref=ts'
    data = m.as_json
    assert_match /^[0-9]+$/, data['likes'].to_s
    assert data['likes'].to_i >= likes.to_i
  end
end
