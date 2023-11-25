require_relative '../test_helper'

class ArchiverWorkerTest < ActiveSupport::TestCase
  def setup
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    Metrics.stubs(:request_metrics_from_facebook).returns({ 'share_count' => 123 })
    clear_bucket
  end
  
  def teardown
    isolated_teardown
  end

  test "should update cache when Archive.org fails the max retries" do
    url = 'https://meedan.com/post/annual-report-2022'
    api_key = create_api_key application_settings: { 'webhook_url': 'https://example.com/webhook.php', 'webhook_token': 'test' }
  
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:any, /archive.org\/wayback\/available/).to_return(body: "{\"archived_snapshots\": {}}", headers: {})
    WebMock.stub_request(:post, /archive.org\/save/).to_return(body: "{\"job_id\":\"spn2-invalid-job-id\"}", headers: {})
    WebMock.stub_request(:get, /archive.org\/save\/status/).to_return(body: "{\"job_id\":\"spn2-invalid-job-id\",\"status\":\"pending\"}", headers: {})
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    m = create_media url: url, key: api_key
    assert_raises Pender::Exception::RetryLater do
      data = m.as_json(archivers: 'archive_org')
      assert_nil data.dig('archives', 'archive_org')
    end

    ArchiverWorker.retries_exhausted_callback({ 'args' => [url, 'archive_org', nil], 'error_message' => 'Test Archiver' }, StandardError.new)
    data = m.as_json
    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_FAILURE'), data.dig('archives', 'archive_org', 'error', 'code')
    assert_equal 'Test Archiver', data.dig('archives', 'archive_org', 'error', 'message')
  end

  test "should update cache when Archive.org raises since first attempt" do
    url = 'https://meedan.com/post/annual-report-2022'
    api_key = create_api_key application_settings: { 'webhook_url': 'https://example.com/webhook.php', 'webhook_token': 'test' }

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:any, /archive.org/).to_raise(Net::ReadTimeout.new('Exception from WebMock'))
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    m = create_media url: url, key: api_key
    assert_raises StandardError do
      data = m.as_json(archivers: 'archive_org')
      assert_nil data.dig('archives', 'archive_org')
    end

    data = m.as_json
    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_ERROR'), data.dig('archives', 'archive_org', 'error', 'code')
    assert_equal 'Net::ReadTimeout with "Exception from WebMock"', data.dig('archives', 'archive_org', 'error', 'message')
  end
end
