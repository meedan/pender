require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class InstagramTest < ActiveSupport::TestCase
  test "should parse Instagram link" do
    m = create_media url: 'https://www.instagram.com/p/BJwkn34AqtN/'
    d = m.as_json
    assert_equal '@megadeth', d['username']
    assert_equal 'item', d['type']
    assert_equal 'Megadeth', d['author_name']
    assert_not_nil d['picture']
  end

  test "should parse Instagram profile" do
    m = create_media url: 'https://www.instagram.com/megadeth'
    d = m.as_json
    assert_equal '@megadeth', d['username']
    assert_equal 'profile', d['type']
    assert_equal 'megadeth', d['title']
    assert_equal 'megadeth', d['author_name']
    assert_match /^http/, d['picture']
  end

  test "should get canonical URL parsed from html tags 2" do
    media1 = create_media url: 'https://www.instagram.com/p/BK4YliEAatH/?taken-by=anxiaostudio'
    media2 = create_media url: 'https://www.instagram.com/p/BK4YliEAatH/'
    assert_equal media1.url, media2.url
  end

  test "should return Instagram author picture" do
    m = create_media url: 'https://www.instagram.com/p/BOXV2-7BPAu'
    d = m.as_json
    assert_match /^http/, d['author_picture']
  end

  test "should parse Instagram post from page and get username and name" do
    m = create_media url: 'https://www.instagram.com/p/BJwkn34AqtN/'
    d = m.as_json
    assert_equal '@megadeth', d['username']
    assert_equal 'Megadeth', d['author_name']
  end

  test "should store data of post returned by instagram api and graphql" do
    m = create_media url: 'https://www.instagram.com/p/BJwkn34AqtN/'
    data = m.as_json
    assert data['raw']['api'].is_a? Hash
    assert !data['raw']['api'].empty?

    assert data['raw']['graphql'].is_a? Hash
    assert !data['raw']['graphql'].empty?

    assert_equal '@megadeth', data[:username]
    assert_match /Peace Sells/, data[:description]
    assert_match /Peace Sells/, data[:title]
    assert !data[:picture].blank?
    assert_equal "https://www.instagram.com/megadeth", data[:author_url]
    assert !data[:html].blank?
    assert !data[:author_picture].blank?
    assert_equal 'Megadeth', data[:author_name]
    assert !data[:published_at].blank?
  end

  test "should store oembed data of a instagram post" do
    m = create_media url: 'https://www.instagram.com/p/BJwkn34AqtN/'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal 'megadeth', data['raw']['oembed']['author_name']
    assert_match /Peace Sells/, data['raw']['oembed']['title']
  end

  test "should use username as author_name on Instagram profile when a full name is not available" do
    m = create_media url: 'https://www.instagram.com/emeliiejanssonn/'
    data = m.as_json
    assert_equal 'emeliiejanssonn', data['author_name']
  end

  test "should not have the subkey json+ld if the tag is not present on page" do
    m = create_media url: 'https://www.instagram.com/emeliiejanssonn/'
    data = m.as_json

    assert data['raw']['json+ld'].nil?
  end
end 
