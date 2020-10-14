require_relative '../test_helper'

class ArchiverWorkerTest < ActiveSupport::TestCase

  test "should update cache when video archiving fails the max retries" do
    Media.any_instance.stubs(:get_metrics)
    url = 'https://twitter.com/meedan/status/1202732707597307905'
    m = create_media url: url
    data = m.as_json
    assert_nil data.dig('archives', 'video_archiver')
    Media.send_to_video_archiver(url, nil)
    ArchiverWorker.retries_exhausted_callback({ 'args' => ['video_archiver', url, nil], 'error_message' => 'Test Archiver' }, StandardError.new)
    data = m.as_json
    assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_FAILURE'), data.dig('archives', 'video_archiver', 'error', 'code')
    assert_equal 'Test Archiver', data.dig('archives', 'video_archiver', 'error', 'message')
    Media.any_instance.unstub(:get_metrics)
  end

  test "should update cache when Archive.org fails the max retries" do
    Media.any_instance.unstub(:archive_to_archive_org)
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'web.archive.org' }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: {})

    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://twitter.com/marcouza/status/875424957613920256'
    m = create_media url: url, key: a
    assert_raises Pender::RetryLater do
      data = m.as_json(archivers: 'archive_org')
      assert_nil data.dig('archives', 'archive_org')
    end

    ArchiverWorker.retries_exhausted_callback({ 'args' => ['archive_org', url, nil], 'error_message' => 'Test Archiver' }, StandardError.new)
    data = m.as_json
    assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_FAILURE'), data.dig('archives', 'archive_org', 'error', 'code')
    assert_equal 'Test Archiver', data.dig('archives', 'archive_org', 'error', 'message')
    WebMock.disable!
  end

  test "should update cache when Archive.org raises the max retries" do
    Media.any_instance.unstub(:archive_to_archive_org)
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'web.archive.org' }
    WebMock.disable_net_connect!(allow: allowed_sites)
    error = Net::ReadTimeout.new('Exception from WebMock')
    WebMock.stub_request(:any, /web.archive.org/).to_raise(Net::ReadTimeout.new('Exception from WebMock'))

    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://twitter.com/marcouza/status/875424957613920256'

    m = create_media url: url, key: a
    assert_raises Net::ReadTimeout do
      data = m.as_json(archivers: 'archive_org')
      assert_nil data.dig('archives', 'archive_org')
    end

    ArchiverWorker.retries_exhausted_callback({ 'args' => ['archive_org', url, nil], 'error_message' => 'Test Archiver' }, StandardError.new)
    data = m.as_json
    assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_FAILURE'), data.dig('archives', 'archive_org', 'error', 'code')
    assert_equal 'Test Archiver', data.dig('archives', 'archive_org', 'error', 'message')
    WebMock.disable!
  end

end
