require 'test_helper'

class OembedItemUnitTest < ActiveSupport::TestCase
  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  def successful_oembed_response
    @oembed_response ||= response_fixture_from_file('oembed-item_youtube.json')
  end

  test ".get_data returns nil if no oembed_url provided" do
    data = OembedItem.new(nil).get_data
    assert data.empty?
  end

  test ".get_data re-requests when initial response is redirect" do
    WebMock.stub_request(:get, /example.com\/oembed/).to_return(status: 302, headers: { location: 'https://example.com/another-oembed' }, body: '')
    WebMock.stub_request(:get, /example.com\/another-oembed/).to_return(status: 200, body: successful_oembed_response)

    data = OembedItem.new('https://example.com/oembed').get_data
    assert_match /<iframe/, data['html'].to_s
    assert_match /src="https:\/\/www.youtube.com\/embed\/S49CN57Y58o\?feature=oembed"/, data['html'].to_s
  end

  test ".get_data assigns error and reports to errbit when response is weird" do
    WebMock.stub_request(:get, /example.com\/oembed/).to_return(status: 200, body: 'asdfasdf')

    data = OembedItem.new('https://example.com/oembed').get_data
    assert_match /JSON::ParserError/, data[:error][:message]
  end

  test ".get_data discards HTML if script.src URL is not HTTPS" do
    oembed_response = <<~JSON
      {
        html: "<script async src=\"http://www.example.com/embed.js\">"
      }
    JSON
    WebMock.stub_request(:get, /example.com\/oembed/).to_return(status: 200, body: oembed_response)

    data = OembedItem.new('https://example.com/oembed').get_data
    assert data['html'].blank?
  end

  test ".get_data discards HTML if iframe.src response includes X-Frame-Options = DENY or SAMEORIGIN" do
    oembed_response = <<~JSON
      {
        html: "<iframe src=\"https://www.example.com/embed.js\">"
      }
    JSON
    WebMock.stub_request(:get, /example.com\/oembed/).to_return(status: 200, headers: { 'X-Frame-Options': 'DENY' }, body: oembed_response)

    data = OembedItem.new('https://example.com/oembed').get_data
    assert data['html'].blank?

    WebMock.stub_request(:get, /example.com\/oembed/).to_return(status: 200, headers: { 'X-Frame-Options': 'SAMEORIGIN' }, body: oembed_response)

    data = OembedItem.new('https://example.com/oembed').get_data
    assert data['html'].blank?
  end

  test ".get_data does not discard HTML for youtube even when iframe.src is set to excluded values" do
    WebMock.stub_request(:get, /example.com\/oembed/).to_return(status: 200, headers: { 'X-Frame-Options': 'DENY' }, body: successful_oembed_response)

    data = OembedItem.new('https://example.com/oembed').get_data
    assert !data['html'].blank?

    WebMock.stub_request(:get, /example.com\/oembed/).to_return(status: 200, headers: { 'X-Frame-Options': 'SAMEORIGIN' }, body: successful_oembed_response)

    data = OembedItem.new('https://example.com/oembed').get_data
    assert !data['html'].blank?
  end
end
