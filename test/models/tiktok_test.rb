require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class TiktokTest < ActiveSupport::TestCase
  test "should parse Tiktok profile" do
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

  # test "should parse Tiktok link" do
  #   m = create_media url: 'https://www.tiktok.com/@scout2015/video/6771039287917038854'
  #   data = m.as_json
  #   assert_equal '@scout2015', data['username']
  #   assert_equal 'item', data['type']
  #   assert_match /Who agrees/, data['title']
  #   assert_match /Scout.+Suki/, data['author_name']
  #   assert_equal '6771039287917038854', data['external_id']
  #   assert_match 'https://www.tiktok.com/@scout2015', data['author_url']
  #   assert_match /^http/, data['picture']
  #   assert_nil data['error']
  # end

  test "should parse Tiktok profile with proxy if title is the site name" do
    blank_page = '<html><head><title>TikTok</title></head><body></body></html>'
    page = '<html><head><title>Huxley the Panda Puppy</title><meta property="og:image" content="https://tiktokcdn.com/image.jpeg"><meta property="twitter:creator" content="Huxley the Panda Puppy"><meta property="og:description" content="Here to make ur day"></head><body></body></html>'
    url = 'https://www.tiktok.com/@huxleythepandapuppy'
    header_options = Media.send(:html_options, url)
    Media.any_instance.stubs(:get_html).with(header_options, true).returns(Nokogiri::HTML(page))
    Media.any_instance.stubs(:get_html).with(header_options, false).returns(Nokogiri::HTML(blank_page))
    Media.any_instance.stubs(:get_html).with(header_options).returns(Nokogiri::HTML(blank_page))
    m = create_media url: url
    data = m.as_json
    assert_equal '@huxleythepandapuppy', data['username']
    assert_equal 'profile', data['type']
    assert_equal 'tiktok', data['provider']
    assert_equal 'Huxley the Panda Puppy', data['title']
    assert_equal 'Huxley the Panda Puppy', data['author_name']
    assert_equal '@huxleythepandapuppy', data['external_id']
    assert_equal 'https://tiktokcdn.com/image.jpeg', data['picture']
    assert_match 'https://www.tiktok.com/@huxleythepandapuppy', m.url
    Media.any_instance.unstub(:get_html)
  end

end
