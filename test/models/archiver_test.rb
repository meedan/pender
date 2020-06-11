require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class ArchiverTest < ActiveSupport::TestCase

  def teardown
    FileUtils.rm_rf(File.join(Rails.root, 'tmp', 'videos'))
  end

  test "should skip screenshots" do
    config = CONFIG['archiver_skip_hosts']

    CONFIG['archiver_skip_hosts'] = ''

    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://checkmedia.org/caio-screenshots/project/1121/media/8390'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    data = m.as_json

    CONFIG['archiver_skip_hosts'] = 'checkmedia.org'

    url = 'https://checkmedia.org/caio-screenshots/project/1121/media/8390?hide_tasks=1'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    data = m.as_json

    CONFIG['archiver_skip_hosts'] = config
  end

  test "should archive to Archive.is" do
    Media.any_instance.unstub(:archive_to_archive_is)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    urls = ['https://twitter.com/marcouza/status/875424957613920256', 'https://twitter.com/marcouza/status/863907872421412864', 'https://twitter.com/marcouza/status/863876311428861952']
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'archive.today' }
    WebMock.disable_net_connect!(allow: allowed_sites)

    assert_nothing_raised do
      WebMock.stub_request(:any, 'http://archive.today/submit/').to_return(body: '', headers: { refresh: '1' })
      m = create_media url: urls[0], key: a
      data = m.as_json

      WebMock.stub_request(:any, 'http://archive.today/submit/').to_return(body: '', headers: { location: 'http://archive.is/test' })
      m = create_media url: urls[1], key: a
      data = m.as_json
    end

    assert_nothing_raised do
      WebMock.stub_request(:any, 'http://archive.today/submit/').to_return(body: '')
      m = create_media url: urls[2], key: a
      data = m.as_json
    end

    WebMock.disable!
  end

  test "should archive to Archive.org" do
    Media.any_instance.unstub(:archive_to_archive_org)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    urls = ['https://twitter.com/marcouza/status/875424957613920256', 'https://twitter.com/marcouza/status/863907872421412864', 'https://twitter.com/ozm/status/1217826699183841280']
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'web.archive.org' }
    WebMock.disable_net_connect!(allow: allowed_sites)

    assert_nothing_raised do
      WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: {})
      m = create_media url: urls[0], key: a
      data = m.as_json
      assert_not_nil data['archives']['archive_org']['error']['message']

      WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/web/123456/test' })
      m = create_media url: urls[1], key: a
      data = m.as_json
      assert_equal 'https://web.archive.org/web/123456/test', data['archives']['archive_org']['location']

      WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'location' => 'https://web.archive.org/web/123456/test' })
      m = create_media url: urls[2], key: a
      data = m.as_json
      assert_equal 'https://web.archive.org/web/123456/test', data['archives']['archive_org']['location']
    end

    WebMock.disable!
  end

  test "should archive Arabics url to Archive.org" do
    Media.any_instance.unstub(:archive_to_archive_org)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'http://www.yallakora.com/ar/news/342470/%D8%A7%D8%AA%D8%AD%D8%A7%D8%AF-%D8%A7%D9%84%D9%83%D8%B1%D8%A9-%D8%B9%D9%86-%D8%A3%D8%B2%D9%85%D8%A9-%D8%A7%D9%84%D8%B3%D8%B9%D9%8A%D8%AF-%D9%84%D8%A7%D8%A8%D8%AF-%D9%85%D9%86-%D8%AD%D9%84-%D9%85%D8%B9-%D8%A7%D9%84%D8%B2%D9%85%D8%A7%D9%84%D9%83/2504'
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'web.archive.org' }
    WebMock.disable_net_connect!(allow: allowed_sites)

    assert_nothing_raised do
      WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/web/123456/test' })
      m = create_media url: url, key: a
      data = m.as_json
    end

    WebMock.disable!
  end

  test "should update media with error when archive to Archive.org fails too many times" do
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'web.archive.org' }
    WebMock.disable_net_connect!(allow: allowed_sites)
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:parse)
    Media.any_instance.stubs(:archive)

    Airbrake.stubs(:configured?).returns(true)
    Airbrake.stubs(:notify)

    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    urls = {
      'https://www.facebook.com/permalink.php?story_fbid=1649526595359937&id=100009078379548' => {code: '404', message: 'Not Found'},
      'http://localhost:3333/unreachable-url' => {code: '403', message: 'Forbidden'},
      'http://www.dutertenewsupdate.info/2018/01/duterte-turned-philippines-into.html' => {code: '502', message: 'Bad Gateway'}
    }

    assert_nothing_raised do
      urls.each_pair do |url, data|
        m = Media.new url: url
        m.as_json(archivers: 'none')
        assert_nil m.data.dig('archives', 'archive_org')
        WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', status: [data[:code], data[:message]], headers: {})

        Media.send_to_archive_org(url.to_s, a.id, 20)
        media_data = Pender::Store.read(Media.get_id(url), :json)
        assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_FAILURE'), media_data.dig('archives', 'archive_org', 'error', 'code')
        assert_equal "#{data[:code]} #{data[:message]}", media_data.dig('archives', 'archive_org', 'error', 'message')
      end
    end

    WebMock.disable!
    Airbrake.unstub(:configured?)
    Airbrake.unstub(:notify)
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_canonical_url)
    Media.any_instance.unstub(:try_https)
    Media.any_instance.unstub(:parse)
    Media.any_instance.unstub(:archive)
  end

  test "should update media with error when request to Archive.org raises error" do
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'web.archive.org' }
    WebMock.disable_net_connect!(allow: allowed_sites)
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:parse)
    Media.any_instance.stubs(:archive)

    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://example.com'

    assert_nothing_raised do
      m = Media.new url: url
      data = m.as_json
      assert m.data.dig('archives', 'archive_org').nil?
      error = Net::ReadTimeout.new('Exception from WebMock')
      WebMock.stub_request(:any, /web.archive.org/).to_raise(Net::ReadTimeout.new('Exception from WebMock'))
      Media.send_to_archive_org(url, a.id, 20)
      media_data = Pender::Store.read(Media.get_id(url), :json)
      assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_ERROR'), media_data.dig('archives', 'archive_org', 'error', 'code')
      assert_equal "#{error.class} #{error.message}", media_data.dig('archives', 'archive_org', 'error', 'message')
    end

    WebMock.disable!
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_canonical_url)
    Media.any_instance.unstub(:try_https)
    Media.any_instance.unstub(:parse)
    Media.any_instance.unstub(:archive)
  end

  test "should not raise error and update media when unexpected response from Archive.is" do
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'archive.today' }
    WebMock.disable_net_connect!(allow: allowed_sites)
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:parse)
    Media.any_instance.stubs(:archive)

    Airbrake.stubs(:configured?).returns(true)
    Airbrake.stubs(:notify)

    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    urls = ['http://www.unexistent-page.html', 'http://localhost:3333/unreachable-url']

    urls.each do |url|
      assert_nothing_raised do
        m = Media.new url: url
        m.as_json
        assert m.data.dig('archives', 'archive_is').nil?
        response = { code: '200', message: 'OK' }
        WebMock.stub_request(:any, 'http://archive.today/submit/').to_return(body: '', status: [response[:code], response[:message]], headers: {})
        Media.send_to_archive_is(url.to_s, a.id, 20)
        media_data = Pender::Store.read(Media.get_id(url), :json)
        assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_FAILURE'), media_data.dig('archives', 'archive_is', 'error', 'code')
        assert_equal "#{response[:code]} #{response[:message]}", media_data.dig('archives', 'archive_is', 'error', 'message')
      end
    end

    WebMock.disable!
    Airbrake.unstub(:configured?)
    Airbrake.unstub(:notify)
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_canonical_url)
    Media.any_instance.unstub(:try_https)
    Media.any_instance.unstub(:parse)
    Media.any_instance.unstub(:archive)
  end

  test "should update media with error when archive to Archive.is fails" do
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'archive.today' }
    WebMock.disable_net_connect!(allow: allowed_sites)
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:parse)
    Media.any_instance.stubs(:archive)

    Airbrake.stubs(:configured?).returns(true)
    Airbrake.stubs(:notify)

    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    urls = {
      'http://www.dutertenewsupdate.info/2018/01/duterte-turned-philippines-into.html' => {code: '200', message: 'OK'}
    }

    assert_nothing_raised do
      urls.each_pair do |url, data|
        m = Media.new url: url
        m.as_json
        assert m.data.dig('archives', 'archive_is').nil?
        WebMock.stub_request(:any, 'http://archive.today/submit/').to_return(body: '', status: [data[:code], data[:message]], headers: { refresh: '0;url=http://archive.today/k5yFO'})
        Media.send_to_archive_is(url.to_s, a.id, 20)
        media_data = Pender::Store.read(Media.get_id(url), :json)
        assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_FAILURE'), media_data.dig('archives', 'archive_is', 'error', 'code')
        assert_equal "#{data[:code]} #{data[:message]}", media_data.dig('archives', 'archive_is', 'error', 'message')
      end
    end

    WebMock.disable!
    Airbrake.unstub(:configured?)
    Airbrake.unstub(:notify)
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_canonical_url)
    Media.any_instance.unstub(:try_https)
    Media.any_instance.unstub(:parse)
    Media.any_instance.unstub(:archive)
  end

  test "should update cache for all archivers if refresh" do
    Media.any_instance.unstub(:archive_to_archive_is)
    Media.any_instance.unstub(:archive_to_archive_org)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    WebMock.enable!
    allowed_sites = lambda{ |uri| !['archive.today', 'web.archive.org'].include?(uri.host) }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, 'http://archive.today/submit/').to_return(body: '', headers: { location: 'archive_is/first_archiving' })

    url = 'https://twitter.com/meedan/status/1095035339226431493'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    m.as_json(archivers: 'archive_is')
    assert_equal({'archive_is' => {"location" => 'archive_is/first_archiving'}}, Pender::Store.read(id, :json)[:archives])

    WebMock.stub_request(:any, 'http://archive.today/submit/').to_return(body: '', headers: { location: 'archive_is/second_archiving' })
    WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/archiving' })
    m.as_json(force: true, archivers: 'archive_is, archive_org')
    assert_equal({'archive_is' => {'location' => 'archive_is/second_archiving'}, 'archive_org' => {'location' => 'https://web.archive.org/archiving' }}, Pender::Store.read(id, :json)[:archives])
    WebMock.disable!
  end

  test "should archive only on new archivers if media on cache, not a refresh and specific archiver" do
    Media.any_instance.unstub(:archive_to_archive_is)
    Media.any_instance.unstub(:archive_to_archive_org)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    WebMock.enable!
    allowed_sites = lambda{ |uri| !['archive.today', 'web.archive.org'].include?(uri.host) }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, 'http://archive.today/submit/').to_return(body: '', headers: { location: 'archive_is/first_archiving' })

    url = 'https://twitter.com/meedan/status/1095034925420560387'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    m.as_json(archivers: 'archive_is')
    assert_equal({'archive_is' => {"location" => 'archive_is/first_archiving'}}, Pender::Store.read(id, :json)[:archives])

    WebMock.stub_request(:any, 'http://archive.today/submit/').to_return(body: '', headers: { location: 'archive_is/second_archiving' })
    WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/archiving' })
    m.as_json(archivers: 'archive_is, archive_org')
    assert_equal({'archive_is' => {'location' => 'archive_is/first_archiving'}, 'archive_org' => {'location' => 'https://web.archive.org/archiving' }}, Pender::Store.read(id, :json)[:archives])
    WebMock.disable!
  end

  test "should not archive again if media on cache have both archivers" do
    Media.any_instance.unstub(:archive_to_archive_is)
    Media.any_instance.unstub(:archive_to_archive_org)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    WebMock.enable!
    allowed_sites = lambda{ |uri| !['archive.today', 'web.archive.org'].include?(uri.host) }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, 'http://archive.today/submit/').to_return(body: '', headers: { location: 'archive_is/first_archiving' })
    WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/archiving' })

    url = 'https://twitter.com/meedan/status/1095034925420560387'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    m.as_json(archivers: 'archive_is, archive_org')
    assert_equal({'archive_is' => {'location' => 'archive_is/first_archiving'}, 'archive_org' => {'location' => 'https://web.archive.org/archiving' }}, Pender::Store.read(id, :json)[:archives])

    WebMock.stub_request(:any, 'http://archive.today/submit/').to_return(body: '', headers: { location: 'archive_is/second_archiving' })
    WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/second_archiving' })

    m.as_json
    assert_equal({'location' => 'archive_is/first_archiving'}, Pender::Store.read(id, :json)[:archives][:archive_is])
    assert_equal({'location' => 'https://web.archive.org/archiving' }, Pender::Store.read(id, :json)[:archives][:archive_org])

    m.as_json(archivers: 'none')
    assert_equal({'location' => 'archive_is/first_archiving'}, Pender::Store.read(id, :json)[:archives][:archive_is])
    assert_equal({'location' => 'https://web.archive.org/archiving' }, Pender::Store.read(id, :json)[:archives][:archive_org])

    WebMock.disable!
  end

  test "return the enabled archivers" do
    assert_equal ['archive_is', 'archive_org'].sort, Media.enabled_archivers(['archive_is', 'archive_org']).keys
    Media::ARCHIVERS['archive_org'][:enabled] = false
    assert_equal ['archive_is'].sort, Media.enabled_archivers(['archive_is', 'archive_org']).keys
    Media::ARCHIVERS['archive_org'][:enabled] = true
  end

  test "should archive to perma.cc and store the URL on archives" do
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://twitter.com/meedan/status/1095755205554200576'
    m = Media.new url: url, key: a
    m.as_json(archivers: 'none')

    Media.any_instance.unstub(:archive_to_perma_cc)
    Pender::Store.stubs(:read).returns(nil)
    response = 'mock';response.stubs(:code).returns('201');response.stubs(:body).returns('{"guid":"AUA8-QNGH"}');response.stubs(:message).returns('OK')
    Net::HTTP.any_instance.stubs(:request).returns(response)
    Media.stubs(:notify_webhook_and_update_cache).with('perma_cc', url, { location: 'http://perma.cc/AUA8-QNGH'}, a.id)
    Media.stubs(:available_archivers).returns(['perma_cc'])
    Media.stubs(:enabled_archivers).returns({ 'perma_cc' => {:patterns=>[/^.*$/], :modifier=>:only, :enabled=>true}})

    m.archive('perma_cc')

    Pender::Store.unstub(:read)
    Net::HTTP.any_instance.unstub(:request)
    Media.unstub(:notify_webhook_and_update_cache)
    Media.notify_webhook_and_update_cache('perma_cc', url, { location: 'http://perma.cc/AUA8-QNGH'}, a.id)

    id = Media.get_id(url)
    cached = Pender::Store.read(id, :json)[:archives]
    assert_equal ['perma_cc'], cached.keys
    assert_equal({ 'location' => 'http://perma.cc/AUA8-QNGH'}, cached['perma_cc'])
    Media.unstub(:enabled_archivers)
    Media.unstub(:available_archivers)
  end

  test "should not try to archive on Perma.cc if already archived on it" do
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://twitter.com/meedan/status/1095755205554200576'
    m = Media.new url: url, key: a
    m.as_json
    Media.update_cache(url, { archives: { 'perma_cc' => { location: 'http://perma.cc/AUA8-QNGH'}}})

    Media.any_instance.unstub(:archive_to_perma_cc)
    Media.stubs(:notify_webhook_and_update_cache).with('perma_cc', url, { location: 'http://perma.cc/AUA8-QNGH'}, a.id).never

    m.archive_to_perma_cc

    Media.unstub(:notify_webhook_and_update_cache)
  end

  test "should update media with error when no key is present and archive to Perma.cc fails" do
    WebMock.enable!
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:parse)
    Media.any_instance.stubs(:archive)

    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'http://example.com'

    assert_nothing_raised do
      m = Media.new url: url
      m.as_json
      assert m.data.dig('archives', 'perma_cc').nil?
      Media.send_to_perma_cc(url.to_s, a.id, 20)
      media_data = Pender::Store.read(Media.get_id(url), :json)
      assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_FAILURE'), media_data.dig('archives', 'perma_cc', 'error', 'code')
      assert_equal "401 Unauthorized", media_data.dig('archives', 'perma_cc', 'error', 'message')
    end

    WebMock.disable!
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_canonical_url)
    Media.any_instance.unstub(:try_https)
    Media.any_instance.unstub(:parse)
    Media.any_instance.unstub(:archive)
  end

  test "should disable Perma.cc archiver if perma_key is not present" do
    assert_nil CONFIG.dig('perma_cc_key')
    assert_equal false, Media::ARCHIVERS['perma_cc'][:enabled]
  end

  test "should return api key settings" do
    key1 = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    key2 = create_api_key application_settings: {}
    key3 = create_api_key
    [key1.id, key2.id, key3.id, -1].each do |id|
      assert_nothing_raised do
        Media.api_key_settings(id)
      end
    end
  end

  test "should call youtube-dl and call video upload when archive video" do
    Media.any_instance.unstub(:archive_to_video)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://twitter.com/meedan/status/1202732707597307905'
    m = Media.new url: url, key: a
    m.as_json

    Media.stubs(:supported_video?).with(url, a.id).returns(true)
    Media.stubs(:notify_video_already_archived).with(url, a.id).returns(nil)

    Media.stubs(:store_video_folder).returns('store_video_folder')
    mock = 'delay'
    Media.stubs(:delay_for).returns(mock)
    mock.stubs(:send_to_video_archiver).returns('delay_send_to_video_archiver')

    assert_equal 'store_video_folder', Media.send_to_video_archiver(url, a.id)
    assert_nil Media.send_to_video_archiver(url, a.id, nil, nil, false)

    not_video_url = 'https://twitter.com/meedan/status/1214263820484521985'
    Media.stubs(:supported_video?).with(not_video_url, a.id).returns(true)
    Media.stubs(:notify_video_already_archived).with(not_video_url, a.id).returns(nil)

    assert_equal 'delay_send_to_video_archiver', Media.send_to_video_archiver(not_video_url, a.id, 20)

    Media.unstub(:supported_video?)
    Media.unstub(:notify_video_already_archived)
    Media.unstub(:store_video_folder)
    Media.unstub(:delay_for)
    Media.unstub(:send_to_video_archiver)
  end

  test "should not raise error when try to download video from non-ascii URL" do
    Media.any_instance.unstub(:archive_to_video)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }

    Media.any_instance.unstub(:archive_to_video)
    Media.stubs(:notify_video_already_archived).returns(nil)

    assert_nothing_raised do
      Media.send_to_video_archiver('http://www.facebook.com/pages/category/Musician-Band/चौधरी-कमला-बाड़मेर-108960273957085', a.id, true, 20)
    end

    Media.unstub(:notify_video_already_archived)
  end

  test "should return false and add error to data when video archiving is not supported" do
    Media.unstub(:supported_video?)
    Media.any_instance.stubs(:parse)
    Media.any_instance.stubs(:get_metrics)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }

    url = 'https://twitter.com/meedan/status/1202732707597307905'
    m = create_media url: url
    m.as_json(archivers: 'none')
    assert Media.supported_video?(m.url, a.id)
    media_data = Pender::Store.read(Media.get_id(url), :json)
    assert_nil media_data.dig('archives', 'video_archiver')

    url = 'https://twitter.com/meedan/status/1214263820484521985'
    m = create_media url: url
    m.as_json(archivers: 'none')
    assert !Media.supported_video?(m.url, a.id)

    media_data = Pender::Store.read(Media.get_id(url), :json)
    assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_NOT_SUPPORTED_MEDIA'), media_data.dig('archives', 'video_archiver', 'error', 'code')
    assert_equal I18n.t(:archiver_not_supported_media, code: 1), media_data.dig('archives', 'video_archiver', 'error', 'message')

    Media.any_instance.unstub(:parse)
    Media.any_instance.unstub(:get_metrics)
  end

  test "should check if non-ascii URL support video download" do
    Media.unstub(:supported_video?)
    assert !Media.supported_video?('http://www.facebook.com/pages/category/Musician-Band/चौधरी-कमला-बाड़मेर-108960273957085')
  end

  test "should notify if URL was already parsed and has a location on data when archive video" do
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://twitter.com/meedan/status/1202732707597307905'

    Pender::Store.stubs(:read).with(Media.get_id(url), :json).returns(nil)
    assert_nil Media.notify_video_already_archived(url, nil)

    data = { archives: { video_archiver: { error: 'could not download video data'}}}
    Pender::Store.stubs(:read).with(Media.get_id(url), :json).returns(data)
    Media.stubs(:notify_webhook).with('video_archiver', url, data, {}).returns('Notify webhook')
    assert_nil Media.notify_video_already_archived(url, nil)

    data[:archives][:video_archiver] = { location: 'path_to_video' }
    Pender::Store.stubs(:read).with(Media.get_id(url), :json).returns(data)
    Media.stubs(:notify_webhook).with('video_archiver', url, data, {}).returns('Notify webhook')
    assert_equal 'Notify webhook', Media.notify_video_already_archived(url, nil)

    Pender::Store.unstub(:read)
    Media.unstub(:notify_webhook)
  end

  test "should archive video info subtitles, thumbnails and update cache" do
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://www.youtube.com/watch?v=1vSJrexmVWU'
    Media.stubs(:supported_video?).with(url, a.id).returns(true)
    Media.stubs(:yt_download_proxy).with(url).returns(nil)
    id = Media.get_id url

    m = create_media url: url, key: a
    data = m.as_json
    assert_nil data.dig('archives', 'video_archiver')
    Media.send_to_video_archiver(url, a.id)

    data = m.as_json
    assert_nil data.dig('archives', 'video_archiver', 'error', 'message')

    folder = File.join(Media.archiving_folder, id)
    assert_equal ['info', 'location', 'subtitles', 'thumbnails', 'videos'], data.dig('archives', 'video_archiver').keys.sort
    assert_equal "#{folder}/#{id}.mp4", data.dig('archives', 'video_archiver', 'location')
    assert_equal "#{folder}/#{id}.info.json", data.dig('archives', 'video_archiver', 'info')
    assert_equal "#{folder}/#{id}.mp4", data.dig('archives', 'video_archiver', 'videos').first
    data.dig('archives', 'video_archiver', 'subtitles').each do |sub|
      assert_match /\A#{folder}\/#{id}.*\.vtt\z/, sub
    end
    data.dig('archives', 'video_archiver', 'thumbnails').each do |thumb|
      assert_match /\A#{folder}\/#{id}.*\.jpg\z/, thumb
    end
    Media.unstub(:supported_video?)
    Media.unstub(:yt_download_proxy)
  end

  test "should handle error and update cache when upload video when archiving fails" do
    Sidekiq::Testing.fake!
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://twitter.com/meedan/status/1202732707597307905'
    Media.stubs(:supported_video?).with(url, a.id).returns(true)
    id = Media.get_id url

    m = create_media url: url, key: a
    data = m.as_json
    assert_nil data.dig('archives', 'video_archiver')

    error = StandardError.new('upload error')
    Pender::Store.stubs(:upload_video_folder).raises(StandardError.new('upload error'))
    Media.send_to_video_archiver(url, a.id, 20)
    data = m.as_json
    assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_ERROR'), data.dig('archives', 'video_archiver', 'error', 'code')
    assert_equal "#{error.class} #{error.message}", data.dig('archives', 'video_archiver', 'error', 'message')

    Pender::Store.unstub(:upload_video_folder)
    Media.unstub(:supported_video?)
  end

  test "should update media with error when supported video call raises on video archiving" do
    Sidekiq::Testing.fake!
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:parse)

    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://example.com'

    assert_nothing_raised do
      m = Media.new url: url
      data = m.as_json
      assert m.data.dig('archives', 'video_archiver').nil?
      error = StandardError.new('some error')
      Media.stubs(:supported_video?).with(url, a.id).raises(error)
      Media.send_to_video_archiver(url, a.id, 20)
      media_data = Pender::Store.read(Media.get_id(url), :json)
      assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_ERROR'), media_data.dig('archives', 'video_archiver', 'error', 'code')
      assert_equal "#{error.class} #{error.message}", media_data.dig('archives', 'video_archiver', 'error', 'message')
    end

    WebMock.disable!
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_canonical_url)
    Media.any_instance.unstub(:try_https)
    Media.any_instance.unstub(:parse)
    Media.unstub(:supported_video?)
  end

  test "should update media with error when video download fails when video archiving" do
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:parse)
    Media.stubs(:supported_video?).returns(true)
    mock = 'status'
    Open3.stubs(:capture3).returns(['', 'ERROR: requested format not available', mock])
    mock.stubs(:success?).returns(false);mock.stubs(:exitstatus).returns(1)

    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://www.tiktok.com/@scout2015/video/6771039287917038854'

    assert_nothing_raised do
      m = Media.new url: url
      data = m.as_json(archivers: 'none')
      assert_nil m.data.dig('archives', 'video_archiver')
      Media.send_to_video_archiver(url, a.id, 20)
      media_data = Pender::Store.read(Media.get_id(url), :json)
      assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_FAILURE'), media_data.dig('archives', 'video_archiver', 'error', 'code')
      assert_equal "1 #{I18n.t(:archiver_video_not_downloaded)}", media_data.dig('archives', 'video_archiver', 'error', 'message')
    end

    WebMock.disable!
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_canonical_url)
    Media.any_instance.unstub(:try_https)
    Media.any_instance.unstub(:parse)
    Media.unstub(:supported_video?)
    Open3.unstub(:capture3)
  end
  test "should generate the public archiving folder for videos" do
    CONFIG.stubs(:dig).with('storage', 'bucket').returns('default_bucket')
    CONFIG.stubs(:dig).with('storage', 'endpoint').returns('http://local-storage')
    CONFIG.stubs(:dig).with('storage', 'video_asset_path').returns(nil)
    CONFIG.stubs(:dig).with('storage', 'video_bucket').returns(nil)
    assert_equal "http://local-storage/#{Pender::Store.video_bucket_name}/video", Media.archiving_folder

    CONFIG.stubs(:dig).with('storage', 'video_bucket').returns('bucket_for_videos')
    assert_equal "http://local-storage/#{Pender::Store.video_bucket_name}/video", Media.archiving_folder

    CONFIG.stubs(:dig).with('storage', 'video_asset_path').returns('http://public-storage/my-videos')
    assert_equal "http://public-storage/my-videos", Media.archiving_folder

    CONFIG.unstub(:dig)
  end

  test "should use proxy to download yt video" do
    url = 'https://www.youtube.com/watch?v=oDNuxzfuq8M'

    CONFIG.stubs(:dig).with('proxy_host').returns('example.proxy')
    CONFIG.stubs(:dig).with('proxy_port').returns('1111')
    CONFIG.stubs(:dig).with('proxy_user_prefix').returns('user-country')
    CONFIG.stubs(:dig).with('proxy_pass').returns('proxy-test')
    assert_match /http:\/\/user-session-\d+:proxy-test@example.proxy:1111/, Media.yt_download_proxy(url)

    CONFIG.stubs(:dig).with('proxy_user_prefix').returns('')
    CONFIG.stubs(:dig).with('proxy_pass').returns('')
    assert_nil Media.yt_download_proxy(url)

    CONFIG.stubs(:dig).returns(nil)
    assert_nil Media.yt_download_proxy(url)

    CONFIG.unstub(:dig)
  end

  test "include error on data when archiver is skipped" do
    config = CONFIG['archiver_skip_hosts']
    CONFIG['archiver_skip_hosts'] = 'example.com'

    url = 'http://example.com'
    m = Media.new url: url
    m.data = Media.minimal_data(m)
    m.archive

    assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_HOST_SKIPPED'), m.data.dig('archives', 'archive_org', 'error', 'code')
    assert_equal I18n.t(:archiver_host_skipped, info: 'example.com'), m.data.dig('archives', 'archive_org', 'error', 'message')

    CONFIG['archiver_skip_hosts'] = config
  end

  test "include error on data when archiver is not present or is disabled" do
    status = Media::ARCHIVERS['archive_org'][:enabled]
    Media::ARCHIVERS['archive_org'][:enabled] = false

    url = 'http://example.com'
    m = Media.new url: url
    m.data = Media.minimal_data(m)
    archiver = 'archive_org,unexistent_archive'
    m.archive(archiver)

    assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_NOT_FOUND'), m.data.dig('archives', 'unexistent_archive', 'error', 'code')
    assert_equal I18n.t(:archiver_not_found), m.data.dig('archives', 'unexistent_archive', 'error', 'message')

    assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_DISABLED'), m.data.dig('archives', 'archive_org', 'error', 'code')
    assert_equal I18n.t(:archiver_disabled), m.data.dig('archives', 'archive_org', 'error', 'message')

    Media::ARCHIVERS['archive_org'][:enabled] = status
  end
end
