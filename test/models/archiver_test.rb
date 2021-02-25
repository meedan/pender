require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class ArchiverTest < ActiveSupport::TestCase

  def teardown
    FileUtils.rm_rf(File.join(Rails.root, 'tmp', 'videos'))
  end

  test "should skip screenshots" do
    stub_configs({'archiver_skip_hosts' => '' })

    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://checkmedia.org/caio-screenshots/project/1121/media/8390'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    data = m.as_json

    stub_configs({'archiver_skip_hosts' => 'checkmedia.org' })

    url = 'https://checkmedia.org/caio-screenshots/project/1121/media/8390?hide_tasks=1'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    data = m.as_json
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
    url = 'https://twitter.com/marcouza/status/863907872421412864'
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'web.archive.org' }
    WebMock.disable_net_connect!(allow: allowed_sites)

    WebMock.stub_request(:post, /web.archive.org\/save/).to_return(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' }.to_json)
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'success', timestamp: 'timestamp'}.to_json)

    m = create_media url: url, key: a
    data = m.as_json(archivers: 'archive_org')
    assert_equal "https://web.archive.org/web/timestamp/#{url}", data['archives']['archive_org']['location']

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
      WebMock.stub_request(:post, /web.archive.org\/save/).to_return(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' }.to_json)
      WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'success', timestamp: 'timestamp'}.to_json)
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
    url = 'https://www.facebook.com/permalink.php?story_fbid=1649526595359937&id=100009078379548'

    assert_raises Pender::RetryLater do
      m = Media.new url: url
      m.as_json(archivers: 'none')
      assert_nil m.data.dig('archives', 'archive_org')
      WebMock.stub_request(:post, /web.archive.org\/save/).to_return(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' }.to_json)
      WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'error', status_ext: 'error:not-found', message: 'The server cannot find the requested resource'}.to_json)

      Media.send_to_archive_org(url.to_s, a.id)
      media_data = Pender::Store.current.read(Media.get_id(url), :json)
      assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_FAILURE'), media_data.dig('archives', 'archive_org', 'error', 'code')
      assert_equal "#{data[:code]} #{data[:message]}", media_data.dig('archives', 'archive_org', 'error', 'message')
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

  test "should update media with error when Archive.org can't archive the url" do
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
      'http://localhost:3333/unreachable-url' => {status_ext: 'error:invalid-url-syntax', message: 'URL syntax is not valid'},
      'http://www.dutertenewsupdate.info/2018/01/duterte-turned-philippines-into.html' => {status_ext: 'error:invalid-host-resolution', message: 'Cannot resolve host'},
    }

    urls.each_pair do |url, data|
      m = Media.new url: url
      m.as_json(archivers: 'none')
      assert_nil m.data.dig('archives', 'archive_org')
      WebMock.stub_request(:any, /web.archive.org\/save/).to_return(body: {status: 'error', status_ext: data[:status_ext], message: data[:message]}.to_json)
      WebMock.stub_request(:get, /archive.org\/wayback/).to_return(body: {"archived_snapshots":{}}.to_json, headers: {})

      Media.send_to_archive_org(url.to_s, a.id)
      media_data = Pender::Store.current.read(Media.get_id(url), :json)
      assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_ERROR'), media_data.dig('archives', 'archive_org', 'error', 'code')
      assert_equal "(#{data[:status_ext]}) #{data[:message]}", media_data.dig('archives', 'archive_org', 'error', 'message')
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

  test "should raise retry error and update media when unexpected response from Archive.is" do
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
      assert_raises Pender::RetryLater do
        m = Media.new url: url
        m.as_json
        assert m.data.dig('archives', 'archive_is').nil?
        response = { code: '200', message: 'OK' }
        WebMock.stub_request(:any, 'http://archive.today/submit/').to_return(body: '', status: [response[:code], response[:message]], headers: {})
        Media.send_to_archive_is(url.to_s, a.id, 20)
        media_data = Pender::Store.current.read(Media.get_id(url), :json)
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

    assert_raises Pender::RetryLater do
      urls.each_pair do |url, data|
        m = Media.new url: url
        m.as_json
        assert m.data.dig('archives', 'archive_is').nil?
        WebMock.stub_request(:any, 'http://archive.today/submit/').to_return(body: '', status: [data[:code], data[:message]], headers: { refresh: '0;url=http://archive.today/k5yFO'})
        Media.send_to_archive_is(url.to_s, a.id, 20)
        media_data = Pender::Store.current.read(Media.get_id(url), :json)
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

  test "should update cache for all archivers sent if refresh" do
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
    assert_equal({'archive_is' => {"location" => 'archive_is/first_archiving'}}, Pender::Store.current.read(id, :json)[:archives])

    WebMock.stub_request(:any, 'http://archive.today/submit/').to_return(body: '', headers: { location: 'archive_is/second_archiving' })
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' }.to_json)
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'success', timestamp: 'timestamp'}.to_json)
    m.as_json(force: true, archivers: 'archive_is, archive_org')
    assert_equal({'archive_is' => {'location' => 'archive_is/second_archiving'}, 'archive_org' => {'location' => "https://web.archive.org/web/timestamp/#{url}" }}, Pender::Store.current.read(id, :json)[:archives])
    WebMock.disable!
  end

  test "should not archive in any archiver if don't send or it's none" do
    Media.any_instance.unstub(:archive_to_archive_is)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    WebMock.enable!
    allowed_sites = lambda{ |uri| !['archive.today', 'web.archive.org'].include?(uri.host) }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, 'http://archive.today/submit/').to_return(body: '', headers: { location: 'archive_is/first_archiving' })

    url = 'https://twitter.com/meedan/status/1095034925420560387'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    m.as_json
    assert_equal({}, Pender::Store.current.read(id, :json)[:archives])

    m.as_json(archivers: '')
    assert_equal({}, Pender::Store.current.read(id, :json)[:archives])

    m.as_json(archivers: nil)
    assert_equal({}, Pender::Store.current.read(id, :json)[:archives])

    m.as_json(archivers: 'none')
    assert_equal({}, Pender::Store.current.read(id, :json)[:archives])

    m.as_json(archivers: 'archive_is')
    assert_equal({'archive_is' => {"location" => 'archive_is/first_archiving'}}, Pender::Store.current.read(id, :json)[:archives])
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
    assert_equal({'archive_is' => {"location" => 'archive_is/first_archiving'}}, Pender::Store.current.read(id, :json)[:archives])

    WebMock.stub_request(:any, 'http://archive.today/submit/').to_return(body: '', headers: { location: 'archive_is/second_archiving' })
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' }.to_json)
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'success', timestamp: 'timestamp'}.to_json)

    m.as_json(archivers: 'archive_is, archive_org')
    assert_equal({'archive_is' => {'location' => 'archive_is/first_archiving'}, 'archive_org' => {'location' => "https://web.archive.org/web/timestamp/#{url}" }}, Pender::Store.current.read(id, :json)[:archives])
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

    url = 'https://twitter.com/meedan/status/1095034925420560387'
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' }.to_json)
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'success', timestamp: 'timestamp'}.to_json)

    id = Media.get_id(url)
    m = create_media url: url, key: a
    m.as_json(archivers: 'archive_is, archive_org')
    assert_equal({'archive_is' => {'location' => 'archive_is/first_archiving'}, 'archive_org' => {'location' => "https://web.archive.org/web/timestamp/#{url}" }}, Pender::Store.current.read(id, :json)[:archives])

    WebMock.stub_request(:any, 'http://archive.today/submit/').to_return(body: '', headers: { location: 'archive_is/second_archiving' })
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' }.to_json)
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'success', timestamp: 'timestamp2'}.to_json)

    m.as_json
    assert_equal({'location' => 'archive_is/first_archiving'}, Pender::Store.current.read(id, :json)[:archives][:archive_is])
    assert_equal({'location' => "https://web.archive.org/web/timestamp/#{url}" }, Pender::Store.current.read(id, :json)[:archives][:archive_org])

    m.as_json(archivers: 'none')
    assert_equal({'location' => 'archive_is/first_archiving'}, Pender::Store.current.read(id, :json)[:archives][:archive_is])
    assert_equal({'location' => "https://web.archive.org/web/timestamp/#{url}" }, Pender::Store.current.read(id, :json)[:archives][:archive_org])

    WebMock.disable!
  end

  test "return the enabled archivers" do
    assert_equal ['archive_is', 'archive_org'].sort, Media.enabled_archivers(['archive_is', 'archive_org']).keys
    Media::ARCHIVERS['archive_org'][:enabled] = false
    assert_equal ['archive_is'].sort, Media.enabled_archivers(['archive_is', 'archive_org']).keys
    Media::ARCHIVERS['archive_org'][:enabled] = true
  end

  test "should archive to perma.cc and store the URL on archives if perma_cc_key is present" do
    Media.any_instance.unstub(:archive_to_perma_cc)
    Media.stubs(:available_archivers).returns(['perma_cc'])
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'api.perma.cc' }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, /api.perma.cc/).to_return(body: '{"guid":"AUA8-QNGH"}')

    url = 'https://twitter.com/meedan/status/1095755205554200576'
    id = Media.get_id(url)

    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test', config: { 'perma_cc_key': 'my-perma-key' }}
    m = Media.new url: url, key: a
    m.as_json(archivers: 'perma_cc')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['perma_cc'], cached.keys
    assert_equal({ 'location' => 'http://perma.cc/AUA8-QNGH'}, cached['perma_cc'])
    Media.unstub(:available_archivers)
    WebMock.disable!
  end

  test "should not try to archive on Perma.cc if already archived on it" do
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test', config: { perma_cc_key: 'perma_key'} }
    url = 'https://twitter.com/meedan/status/1095755205554200576'
    m = Media.new url: url, key: a
    m.as_json
    Media.update_cache(url, { archives: { 'perma_cc' => { location: 'http://perma.cc/AUA8-QNGH'}}})

    Media.any_instance.unstub(:archive_to_perma_cc)
    Media.stubs(:notify_webhook_and_update_cache).with('perma_cc', url, { location: 'http://perma.cc/AUA8-QNGH'}, a.id).never

    m.archive_to_perma_cc

    Media.unstub(:notify_webhook_and_update_cache)
  end

  test "should update media with error when archive to Perma.cc fails" do
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:parse)
    Media.any_instance.stubs(:archive)

    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test', config: { perma_cc_key: 'perma_key'} }
    url = 'http://example.com'

    assert_raises Pender::RetryLater do
      m = Media.new url: url, key: a
      m.as_json
      assert m.data.dig('archives', 'perma_cc').nil?
      Media.send_to_perma_cc(url.to_s, a.id, 20)
      media_data = Pender::Store.current.read(Media.get_id(url), :json)
      assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_FAILURE'), media_data.dig('archives', 'perma_cc', 'error', 'code')
      assert_equal "401 Unauthorized", media_data.dig('archives', 'perma_cc', 'error', 'message')
    end

    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_canonical_url)
    Media.any_instance.unstub(:try_https)
    Media.any_instance.unstub(:parse)
    Media.any_instance.unstub(:archive)
  end

  test "should add disabled Perma.cc archiver error message if perma_key is not present" do
    Media.any_instance.unstub(:archive_to_perma_cc)
    Media.stubs(:available_archivers).returns(['perma_cc'])

    url = 'https://twitter.com/meedan/status/1095755205554200576'
    id = Media.get_id(url)

    m = Media.new url: url, key: create_api_key
    m.as_json(archivers: 'perma_cc')
    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_MISSING_KEY'), cached.dig('perma_cc', 'error', 'code')
    assert_equal I18n.t(:archiver_missing_key), cached.dig('perma_cc', 'error', 'message')

    Media.unstub(:available_archivers)
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
    Media.stubs(:system).returns(`(exit 0)`)
    assert_equal 'store_video_folder', Media.send_to_video_archiver(url, a.id)
    assert_nil Media.send_to_video_archiver(url, a.id, false)

    Media.unstub(:supported_video?)
    Media.unstub(:notify_video_already_archived)
    Media.unstub(:store_video_folder)
    Media.unstub(:system)
  end

  test "should return false and add error to data when video archiving is not supported" do
    Media.unstub(:supported_video?)
    Media.any_instance.stubs(:parse)
    Media.any_instance.stubs(:get_metrics)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }

    Media.stubs(:system).returns(`(exit 0)`)
    url = 'https://twitter.com/meedan/status/1202732707597307905'
    m = create_media url: url
    m.as_json(archivers: 'none')
    assert Media.supported_video?(m.url, a.id)
    media_data = Pender::Store.current.read(Media.get_id(url), :json)
    assert_nil media_data.dig('archives', 'video_archiver')

    Media.stubs(:system).returns(`(exit 1)`)
    url = 'https://twitter.com/meedan/status/1214263820484521985'
    m = create_media url: url
    m.as_json(archivers: 'none')
    assert !Media.supported_video?(m.url, a.id)

    media_data = Pender::Store.current.read(Media.get_id(url), :json)
    assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_NOT_SUPPORTED_MEDIA'), media_data.dig('archives', 'video_archiver', 'error', 'code')
    assert_equal I18n.t(:archiver_not_supported_media, code: 1), media_data.dig('archives', 'video_archiver', 'error', 'message')

    Media.any_instance.unstub(:parse)
    Media.any_instance.unstub(:get_metrics)
    Media.any_instance.unstub(:system)
  end

  test "should check if non-ascii URL support video download" do
    Media.unstub(:supported_video?)
    assert !Media.supported_video?('http://example.com/pages/category/Musician-Band/चौधरी-कमला-बाड़मेर-108960273957085')
  end

  test "should notify if URL was already parsed and has a location on data when archive video" do
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://twitter.com/meedan/status/1202732707597307905'

    Pender::Store.any_instance.stubs(:read).with(Media.get_id(url), :json).returns(nil)
    assert_nil Media.notify_video_already_archived(url, nil)

    data = { archives: { video_archiver: { error: 'could not download video data'}}}
    Pender::Store.any_instance.stubs(:read).with(Media.get_id(url), :json).returns(data)
    Media.stubs(:notify_webhook).with('video_archiver', url, data, {}).returns('Notify webhook')
    assert_nil Media.notify_video_already_archived(url, nil)

    data[:archives][:video_archiver] = { location: 'path_to_video' }
    Pender::Store.any_instance.stubs(:read).with(Media.get_id(url), :json).returns(data)
    Media.stubs(:notify_webhook).with('video_archiver', url, data, {}).returns('Notify webhook')
    assert_equal 'Notify webhook', Media.notify_video_already_archived(url, nil)

    Pender::Store.any_instance.unstub(:read)
    Media.unstub(:notify_webhook)
  end

  # FIXME Mocking Youtube-DL to avoid `HTTP Error 429: Too Many Requests`
  test "should archive video info subtitles, thumbnails and update cache" do
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://www.youtube.com/watch?v=1vSJrexmVWU'
    id = Media.get_id url

    Media.stubs(:supported_video?).with(url, a.id).returns(true)
    Media.stubs(:system).returns(`(exit 0)`)
    local_folder = File.join(Rails.root, 'tmp', 'videos', id)
    video_files = "#{local_folder}/#{id}/#{id}.es.vtt", "#{local_folder}/#{id}/#{id}.jpg", "#{local_folder}/#{id}/#{id}.vtt", "#{local_folder}/#{id}/#{id}.mp4", "#{local_folder}/#{id}/#{id}.jpg", "#{local_folder}/#{id}/#{id}.info.json"
    Dir.stubs(:glob).returns(video_files)
    Pender::Store.any_instance.stubs(:upload_video_folder)

    m = create_media url: url, key: a
    data = m.as_json
    assert_nil data.dig('archives', 'video_archiver')
    Media.send_to_video_archiver(url, a.id, 20)

    data = m.as_json
    assert_nil data.dig('archives', 'video_archiver', 'error', 'message')

    folder = File.join(Media.archiving_folder, id)
    assert_equal ['info', 'location', 'subtitles', 'thumbnails', 'videos'], data.dig('archives', 'video_archiver').keys.sort
    assert_equal "#{folder}/#{id}.mp4", data.dig('archives', 'video_archiver', 'location')
    assert_equal "#{folder}/#{id}.info.json", data.dig('archives', 'video_archiver', 'info')
    assert_equal "#{folder}/#{id}.mp4", data.dig('archives', 'video_archiver', 'videos').first
    data.dig('archives', 'video_archiver', 'subtitles').each do |sub|
      assert_match /\A#{folder}\/#{id}/, sub
    end
    data.dig('archives', 'video_archiver', 'thumbnails').each do |thumb|
      assert_match /\A#{folder}\/#{id}.*\.jpg\z/, thumb
    end
    Media.unstub(:supported_video?)
    Media.unstub(:system)
    Dir.unstub(:glob)
    Pender::Store.any_instance.unstub(:upload_video_folder)
  end

  test "should raise retry error when video archiving fails" do
    Sidekiq::Testing.fake!
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://twitter.com/meedan/status/1202732707597307905'
    Media.stubs(:supported_video?).with(url, a.id).returns(true)
    id = Media.get_id url
    m = create_media url: url, key: a
    data = m.as_json
    assert_nil data.dig('archives', 'video_archiver')

    Media.stubs(:system).returns(`(exit 1)`)
    not_video_url = 'https://twitter.com/meedan/status/1214263820484521985'
    Media.stubs(:supported_video?).with(not_video_url, a.id).returns(true)
    Media.stubs(:notify_video_already_archived).with(not_video_url, a.id).returns(nil)

    Media.stubs(:system).returns(`(exit 1)`)
    assert_raises Pender::RetryLater do
      Media.send_to_video_archiver(not_video_url, a.id)
    end
    Media.unstub(:supported_video?)
    Media.unstub(:notify_video_already_archived)
    Media.unstub(:system)
  end

  test "should update media with error when supported video call raises on video archiving" do
    Sidekiq::Testing.fake!
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:parse)

    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://example.com'

    assert_raises Pender::RetryLater do
      m = Media.new url: url
      data = m.as_json
      assert m.data.dig('archives', 'video_archiver').nil?
      error = StandardError.new('some error')
      Media.stubs(:supported_video?).with(url, a.id).raises(error)
      Media.send_to_video_archiver(url, a.id, 20)
      media_data = Pender::Store.current.read(Media.get_id(url), :json)
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
    Media.stubs(:system).returns(`(exit 1)`)

    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://www.tiktok.com/@scout2015/video/6771039287917038854'

    assert_raises Pender::RetryLater do
      m = Media.new url: url
      data = m.as_json(archivers: 'none')
      assert_nil m.data.dig('archives', 'video_archiver')
      Media.send_to_video_archiver(url, a.id, 20)
      media_data = Pender::Store.current.read(Media.get_id(url), :json)
      assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_FAILURE'), media_data.dig('archives', 'video_archiver', 'error', 'code')
      assert_equal "1 #{I18n.t(:archiver_video_not_downloaded)}", media_data.dig('archives', 'video_archiver', 'error', 'message')
    end

    WebMock.disable!
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_canonical_url)
    Media.any_instance.unstub(:try_https)
    Media.any_instance.unstub(:parse)
    Media.unstub(:supported_video?)
    Media.unstub(:system)
  end

  test "should generate the public archiving folder for videos" do
    a = create_api_key application_settings: { config: { storage_bucket: 'default-bucket', storage_video_asset_path: nil, storage_video_bucket: nil }}
    ApiKey.current = a

    assert_match /#{PenderConfig.get('storage_endpoint')}\/default-bucket\d*\/video/, Media.archiving_folder

    a.application_settings[:config][:storage_video_bucket] = 'bucket-for-videos'; a.save
    ApiKey.current = a
    Pender::Store.current = nil
    PenderConfig.current = nil
    assert_match /#{PenderConfig.get('storage_endpoint')}\/bucket-for-videos\d*\/video/, Media.archiving_folder

    a.application_settings[:config][:storage_video_asset_path] = 'http://public-storage/my-videos'; a.save
    ApiKey.current = a
    Pender::Store.current = nil
    PenderConfig.current = nil
    assert_equal "http://public-storage/my-videos", Media.archiving_folder
  end

  test "include error on data when cannot use archiver" do
    skip = ENV['archiver_skip_hosts']
    ENV['archiver_skip_hosts'] = 'example.com'

    url = 'http://example.com'
    m = Media.new url: url
    m.data = Media.minimal_data(m)

    m.archive('archive_org')
    assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_HOST_SKIPPED'), m.data.dig('archives', 'archive_org', 'error', 'code')
    assert_equal I18n.t(:archiver_host_skipped, info: 'example.com'), m.data.dig('archives', 'archive_org', 'error', 'message')
    ENV['archiver_skip_hosts'] = ''

    PenderConfig.reload
    status = Media::ARCHIVERS['archive_org'][:enabled]
    Media::ARCHIVERS['archive_org'][:enabled] = false

    m.archive('archive_org,unexistent_archive')

    assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_NOT_FOUND'), m.data.dig('archives', 'unexistent_archive', 'error', 'code')
    assert_equal I18n.t(:archiver_not_found), m.data.dig('archives', 'unexistent_archive', 'error', 'message')
    assert_equal LapisConstants::ErrorCodes::const_get('ARCHIVER_DISABLED'), m.data.dig('archives', 'archive_org', 'error', 'code')
    assert_equal I18n.t(:archiver_disabled), m.data.dig('archives', 'archive_org', 'error', 'message')
    Media::ARCHIVERS['archive_org'][:enabled] = status
    ENV['archiver_skip_hosts'] = skip
  end

  test "should send to video archiver when call archive to video" do
    Media.any_instance.unstub(:archive_to_video)
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)

    Sidekiq::Testing.fake! do
      url = 'http://example.com'
      m = Media.new url: url
      assert_difference 'ArchiverWorker.jobs.size', 1 do
        m.archive_to_video
      end
    end

    Media.unstub(:follow_redirections)
    Media.unstub(:get_canonical_url)
    Media.unstub(:try_https)
  end

  test "should get proxy to download video from api key if present" do
    api_key = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://www.youtube.com/watch?v=unv9aPZYF6E'
    m = Media.new url: url, key: api_key

    assert_nil Media.yt_download_proxy(m.url)

    api_key.application_settings = { config: { ytdl_proxy_host: 'my-proxy.mine', ytdl_proxy_port: '1111', ytdl_proxy_user_prefix: 'my-user-prefix', ytdl_proxy_pass: '12345' }}; api_key.save
    PenderConfig.current = nil
    m = Media.new url: url, key: api_key
    assert_equal 'http://my-user-prefix:12345@my-proxy.mine:1111', Media.yt_download_proxy(m.url)
  end

  test "should use api key config when archiving video if present" do
    Media.unstub(:supported_video?)
    Media.stubs(:system).returns(`(exit 0)`)

    config = {}
    %w(ytdl_proxy_host ytdl_proxy_port ytdl_proxy_user_prefix ytdl_proxy_pass storage_endpoint storage_access_key storage_secret_key storage_bucket storage_bucket_region storage_video_bucket).each do |config_key|
      config[config_key] = PenderConfig.get(config_key, "test_#{config_key}")
    end

    url = 'https://www.youtube.com/watch?v=o1V1LnUU5VM'

    ApiKey.current = PenderConfig.current = Pender::Store.current = nil
    api_key = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    Media.send_to_video_archiver(url, api_key.id)
    assert_equal api_key, ApiKey.current
    %w(endpoint access_key secret_key bucket bucket_region medias_asset_path).each do |key|
      assert !PenderConfig.current("storage_#{key}").blank?
      assert !Pender::Store.current.instance_variable_get(:@storage)[key].blank?
    end

    ApiKey.current = PenderConfig.current = Pender::Store.current = nil
    api_key.application_settings = { config: { ytdl_proxy_host: 'my-proxy.mine', ytdl_proxy_port: '1111', ytdl_proxy_user_prefix: 'my-user-prefix', ytdl_proxy_pass: '12345', storage_endpoint: config['storage_endpoint'], storage_access_key: config['storage_access_key'], storage_secret_key: config['storage_secret_key'], storage_bucket: 'my-bucket', storage_bucket_region: config['storage_bucket_region'], storage_video_bucket: 'video-bucket'}}; api_key.save
    Media.send_to_video_archiver(url, api_key.id, 20)
    assert_equal api_key, ApiKey.current
    %w(host port user_prefix pass).each do |key|
      assert_equal api_key.settings[:config]["ytdl_proxy_#{key}"], PenderConfig.current("ytdl_proxy_#{key}")
    end
    %w(endpoint access_key secret_key bucket bucket_region video_bucket).each do |key|
      assert_equal api_key.settings[:config]["storage_#{key}"], PenderConfig.current("storage_#{key}")
      assert_equal api_key.settings[:config]["storage_#{key}"], Pender::Store.current.instance_variable_get(:@storage)[key]
    end

    Media.unstub(:system)
  end

  test "should return true and get available snapshot if page was already archived on Archive.org" do
    url = 'https://example.com/'
    m = Media.new url: url
    m.as_json

    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'archive.org' }
    WebMock.disable_net_connect!(allow: allowed_sites)

    WebMock.stub_request(:get, /archive.org\/wayback\/available?.+url=#{url}/).to_return(body: {"archived_snapshots":{ closest: { available: true, url: 'http://web.archive.org/web/20210223111252/http://example.com/' }}}.to_json)

    assert_equal true, Media.get_available_archive_org_snapshot(url, nil)
    data = m.as_json
    assert_equal 'http://web.archive.org/web/20210223111252/http://example.com/' , data['archives']['archive_org']['location']

    WebMock.disable!
  end

  test "should return nil if page was not previously archived on Archive.org" do
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'archive.org' }
    WebMock.disable_net_connect!(allow: allowed_sites)

    WebMock.stub_request(:get, /archive.org\/wayback/).to_return(body: {"archived_snapshots":{}}.to_json)

    url = 'https://example.com/'
    assert_nil Media.get_available_archive_org_snapshot(url, nil)

    WebMock.disable!
  end
end
