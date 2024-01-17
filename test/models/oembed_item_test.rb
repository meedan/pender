require 'test_helper'
require 'stringio'

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

  def request_url
    'https://example.com/article'
  end

  test ".get_data returns emptpy data object if no oembed_url provided" do
    data = OembedItem.new(nil, nil).get_data
    assert data[:error].blank?
    assert data[:raw][:oembed].blank?
  end

  test ".get_data re-requests when initial response is redirect" do
    WebMock.stub_request(:get, /example.com\/oembed/).to_return(status: 302, headers: { location: 'https://example.com/another-oembed' }, body: '')
    WebMock.stub_request(:get, /example.com\/another-oembed/).to_return(status: 200, body: successful_oembed_response)

    data = OembedItem.new(request_url, 'https://example.com/oembed').get_data
    assert_match /<iframe/, data[:raw][:oembed][:html].to_s
    assert_match /src="https:\/\/www.youtube.com\/embed\/S49CN57Y58o\?feature=oembed"/, data[:raw][:oembed][:html].to_s
  end

  test ".get_data assigns error in raw oembed when response is weird, without reporting to errbit" do
    WebMock.stub_request(:get, /example.com\/oembed/).to_return(status: 200, body: 'asdfasdf')

    data = OembedItem.new(request_url, 'https://example.com/oembed').get_data
    assert_match /asdfasdf/, data[:raw][:oembed][:error][:message]
  end

  test ".get_data assigns top-level and reports to errbit for non-parsing errors" do
    WebMock.stub_request(:get, /example.com\/oembed/).to_raise(StandardError.new("fake for test"))

    data = OembedItem.new(request_url, 'https://example.com/oembed').get_data
    assert_match /StandardError/, data[:error][:message]
  end

  test ".get_data discards HTML if script.src URL is not HTTPS" do
    oembed_response = <<~JSON
      {
        html: "<script async src=\"http://www.example.com/embed.js\">"
      }
    JSON
    WebMock.stub_request(:get, /example.com\/oembed/).to_return(status: 200, body: oembed_response)

    data = OembedItem.new(request_url, 'https://example.com/oembed').get_data
    assert data[:raw][:oembed][:html].blank?
  end

  test ".get_data discards HTML if iframe.src response includes X-Frame-Options = DENY or SAMEORIGIN" do
    oembed_response = <<~JSON
      {
        html: "<iframe src=\"https://www.example.com/embed.js\">"
      }
    JSON
    WebMock.stub_request(:get, /example.com\/oembed/).to_return(status: 200, headers: { 'X-Frame-Options': 'DENY' }, body: oembed_response)

    data = OembedItem.new(request_url, 'https://example.com/oembed').get_data
    assert data[:raw][:oembed]['html'].blank?

    WebMock.stub_request(:get, /example.com\/oembed/).to_return(status: 200, headers: { 'X-Frame-Options': 'SAMEORIGIN' }, body: oembed_response)

    data = OembedItem.new(request_url, 'https://example.com/oembed').get_data
    assert data[:raw][:oembed]['html'].blank?
  end

  test ".get_data does not discard HTML for youtube even when iframe.src is set to excluded values" do
    WebMock.stub_request(:get, /example.com\/oembed/).to_return(status: 200, headers: { 'X-Frame-Options': 'DENY' }, body: successful_oembed_response)

    data = OembedItem.new(request_url, 'https://example.com/oembed').get_data
    assert !data[:raw][:oembed][:html].empty?

    WebMock.stub_request(:get, /example.com\/oembed/).to_return(status: 200, headers: { 'X-Frame-Options': 'SAMEORIGIN' }, body: successful_oembed_response)

    data = OembedItem.new(request_url, 'https://example.com/oembed').get_data
    assert !data[:raw][:oembed][:html].empty?
  end

  test "converts relative oembed URLs as absolute URLs" do
    WebMock.stub_request(:get, /example.com\/foo/).to_return(status: 200, headers: { 'X-Frame-Options': 'SAMEORIGIN' }, body: successful_oembed_response)

    item = OembedItem.new('https://example.com', '/foo')

    assert_equal 'https://example.com/foo', item.oembed_uri.to_s
  end

  test "logs oembed request failures" do
    logger_output = StringIO.new
    Rails.logger = Logger.new(logger_output)
    WebMock.stub_request(:get, /example.com\/unreachable/).to_raise(StandardError)

    OembedItem.new('https://example.com', '/unreachable').get_data

    assert_includes logger_output.string, "[Parser] Could not send oembed request"
  end

  test "sets empty oembed_uri if URI is bunk for some reason" do
    item = OembedItem.new('asasdf', 'asasdf')
    assert_nil item.oembed_uri
    assert item.get_data[:raw][:oembed].blank?
  end

  test "should not explode if infinite redirect" do
    WebMock.stub_request(:get, /example.com/).and_return(status: 308, body: '', headers: { location: 'http://example.com/original'} )

    item = OembedItem.new('http://example.com/original', 'http://example.com/oembed')
    assert !item.get_data.blank?
  end
end
