require_relative '../test_helper'

class ArchiverWorkerTest < ActiveSupport::TestCase

  test "should update cache when video archiving fails the max retries" do
    Metrics.stubs(:get_metrics_from_facebook_in_background)
    url = 'https://twitter.com/meedan/status/1202732707597307905'
    m = create_media url: url
    data = m.as_json
    assert_nil data.dig('archives', 'video_archiver')
    Media.send_to_video_archiver(url, nil)
    ArchiverWorker.retries_exhausted_callback({ 'args' => [url, 'video_archiver', nil], 'error_message' => 'Test Archiver' }, StandardError.new)
    data = m.as_json
    assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_FAILURE'), data.dig('archives', 'video_archiver', 'error', 'code')
    assert_equal 'Test Archiver', data.dig('archives', 'video_archiver', 'error', 'message')
    Metrics.unstub(:get_metrics_from_facebook_in_background)
  end

  test "should update cache when Archive.org fails the max retries" do
    Media.any_instance.unstub(:archive_to_archive_org)
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'web.archive.org' }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, /archive.org\/wayback\/available/).to_return(body: "{\"archived_snapshots\": {}}", headers: {})
    WebMock.stub_request(:post, /archive.org\/save/).to_return(body: "{\"job_id\":\"spn2-invalid-job-id\"}", headers: {})
    WebMock.stub_request(:get, /archive.org\/save\/status/).to_return(body: "{\"job_id\":\"spn2-invalid-job-id\",\"status\":\"pending\"}", headers: {})
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    a = create_api_key application_settings: { 'webhook_url': 'https://example.com/webhook.php', 'webhook_token': 'test' }
    url = 'https://twitter.com/marcouza/status/875424957613920256'
    m = create_media url: url, key: a
    assert_raises Pender::RetryLater do
      data = m.as_json(archivers: 'archive_org')
      assert_nil data.dig('archives', 'archive_org')
    end

    ArchiverWorker.retries_exhausted_callback({ 'args' => [url, 'archive_org', nil], 'error_message' => 'Test Archiver' }, StandardError.new)
    data = m.as_json
    assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_FAILURE'), data.dig('archives', 'archive_org', 'error', 'code')
    assert_equal 'Test Archiver', data.dig('archives', 'archive_org', 'error', 'message')
  ensure
    WebMock.disable!
  end

  test "should update cache when Archive.org raises since first attempt" do
    Media.any_instance.unstub(:archive_to_archive_org)
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'web.archive.org' }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, /archive.org/).to_raise(Net::ReadTimeout.new('Exception from WebMock'))
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    a = create_api_key application_settings: { 'webhook_url': 'https://example.com/webhook.php', 'webhook_token': 'test' }
    url = 'https://twitter.com/marcouza/status/875424957613920256'

    m = create_media url: url, key: a
    assert_raises Pender::RetryLater do
      data = m.as_json(archivers: 'archive_org')
      assert_nil data.dig('archives', 'archive_org')
    end

    data = m.as_json
    assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_ERROR'), data.dig('archives', 'archive_org', 'error', 'code')
    assert_equal 'Net::ReadTimeout with "Exception from WebMock"', data.dig('archives', 'archive_org', 'error', 'message')
  ensure
    WebMock.disable!
  end
end
