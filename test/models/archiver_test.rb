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
    allowed_sites = lambda{ |uri| uri.host != 'archive.is' }
    WebMock.disable_net_connect!(allow: allowed_sites)

    assert_nothing_raised do
      WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { refresh: '1' })
      m = create_media url: urls[0], key: a
      data = m.as_json

      WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { location: 'http://archive.is/test' })
      m = create_media url: urls[1], key: a
      data = m.as_json
    end

    assert_nothing_raised do
      WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '')
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

  test "should update media with error when archive to Archive.org fails" do
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
        m.as_json
        assert m.data.dig('archives', 'archive_org').nil?
        WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', status: [data[:code], data[:message]], headers: {})
        Media.send_to_archive_org(url.to_s, a.id, 20)
        media_data = Pender::Store.read(Media.get_id(url), :json)
        assert_equal({"message"=>I18n.t(:could_not_archive, error_message: data[:message]), "code"=>data[:code]}, media_data.dig('archives', 'archive_org', 'error'))
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

  test "should update media with error when reques to Archive.org fails" do
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
      WebMock.stub_request(:any, /web.archive.org/).to_raise(Net::ReadTimeout)
      Media.send_to_archive_org(url, a.id)
      media_data = Pender::Store.read(Media.get_id(url), :json)
      assert_match /Could not archive/, media_data.dig('archives', 'archive_org', 'error', 'message')
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
    allowed_sites = lambda{ |uri| uri.host != 'archive.is' }
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
        WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', status: [response[:code], response[:message]], headers: {})
        Media.send_to_archive_is(url.to_s, a.id, 20)
        media_data = Pender::Store.read(Media.get_id(url), :json)
        assert_equal({"message"=>I18n.t(:could_not_archive, error_message: response[:message]), "code"=> response[:code]}, media_data.dig('archives', 'archive_is', 'error'))
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
    allowed_sites = lambda{ |uri| uri.host != 'archive.is' }
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
        WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', status: [data[:code], data[:message]], headers: { refresh: '0;url=http://archive.is/k5yFO'})
        Media.send_to_archive_is(url.to_s, a.id, 20)
        media_data = Pender::Store.read(Media.get_id(url), :json)
        assert_equal({"message"=>I18n.t(:could_not_archive, error_message: data[:message]), "code"=>data[:code]}, media_data.dig('archives', 'archive_is', 'error'))
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

  test "should archive on all archivers when list is nil" do
    Media.any_instance.unstub(:archive_to_archive_is)
    Media.any_instance.unstub(:archive_to_archive_org)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    WebMock.enable!
    allowed_sites = lambda{ |uri| !['archive.is', 'web.archive.org'].include?(uri.host) }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { location: 'http://archive.is/test' })
    WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/web/123456/test' })

    url = 'https://twitter.com/meedan/status/1095810431367737344'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    m.as_json
    assert_equal({"archive_is"=>{"location"=>"http://archive.is/test"}, "archive_org"=>{"location"=>"https://web.archive.org/web/123456/test"}}, Pender::Store.read(id, :json)[:archives])
    WebMock.disable!
  end

  test "should not archive when list is none" do
    Media.any_instance.unstub(:archive_to_archive_is)
    Media.any_instance.unstub(:archive_to_archive_org)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    WebMock.enable!
    allowed_sites = lambda{ |uri| !['archive.is', 'web.archive.org'].include?(uri.host) }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { location: 'http://archive.is/test' })
    WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/web/123456/test' })

    url = 'https://twitter.com/meedan/status/1095711665939759110'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    m.as_json(archivers: 'none')
    assert_equal({}, Pender::Store.read(id, :json)[:archives])
    WebMock.disable!
  end


  [['archive_is'], ['archive_org'], ['archive_is', 'archive_org']].each do |archivers|
    test "should archive on `#{archivers}`" do
      Media.any_instance.unstub(:archive_to_archive_is)
      Media.any_instance.unstub(:archive_to_archive_org)
      a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
      WebMock.enable!
      allowed_sites = lambda{ |uri| !['archive.is', 'web.archive.org'].include?(uri.host) }
      WebMock.disable_net_connect!(allow: allowed_sites)
      WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { location: 'http://archive.is/test' })
      WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/web/123456/test' })
      archived = {"archive_is"=>{"location"=>"http://archive.is/test"}, "archive_org"=>{"location"=>"https://web.archive.org/web/123456/test"}}

      url = 'https://twitter.com/meedan/status/1095755205554200576'
      id = Media.get_id(url)
      m = create_media url: url, key: a
      m.as_json(archivers: archivers.join(','))
      cached = Pender::Store.read(id, :json)[:archives]
      assert_equal archivers, cached.keys
      archivers.each do |archiver|
        assert_equal(archived[archiver], cached[archiver])
      end
      WebMock.disable!
    end
  end

  test "should update cache for all archivers if refresh" do
    Media.any_instance.unstub(:archive_to_archive_is)
    Media.any_instance.unstub(:archive_to_archive_org)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    WebMock.enable!
    allowed_sites = lambda{ |uri| !['archive.is', 'web.archive.org'].include?(uri.host) }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { location: 'archive_is/first_archiving' })

    url = 'https://twitter.com/meedan/status/1095035339226431493'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    m.as_json(archivers: 'archive_is')
    assert_equal({'archive_is' => {"location" => 'archive_is/first_archiving'}}, Pender::Store.read(id, :json)[:archives])

    WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { location: 'archive_is/second_archiving' })
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
    allowed_sites = lambda{ |uri| !['archive.is', 'web.archive.org'].include?(uri.host) }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { location: 'archive_is/first_archiving' })

    url = 'https://twitter.com/meedan/status/1095034925420560387'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    m.as_json(archivers: 'archive_is')
    assert_equal({'archive_is' => {"location" => 'archive_is/first_archiving'}}, Pender::Store.read(id, :json)[:archives])

    WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { location: 'archive_is/second_archiving' })
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
    allowed_sites = lambda{ |uri| !['archive.is', 'web.archive.org'].include?(uri.host) }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { location: 'archive_is/first_archiving' })
    WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/archiving' })

    url = 'https://twitter.com/meedan/status/1095034925420560387'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    m.as_json(archivers: 'archive_is, archive_org')
    assert_equal({'archive_is' => {'location' => 'archive_is/first_archiving'}, 'archive_org' => {'location' => 'https://web.archive.org/archiving' }}, Pender::Store.read(id, :json)[:archives])

    WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { location: 'archive_is/second_archiving' })
    WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/second_archiving' })

    m.as_json
    assert_equal({'archive_is' => {'location' => 'archive_is/first_archiving'}, 'archive_org' => {'location' => 'https://web.archive.org/archiving' }}, Pender::Store.read(id, :json)[:archives])

    m.as_json(archivers: 'none')
    assert_equal({'archive_is' => {'location' => 'archive_is/first_archiving'}, 'archive_org' => {'location' => 'https://web.archive.org/archiving' }}, Pender::Store.read(id, :json)[:archives])

    WebMock.disable!
  end

  test "return the enabled archivers" do
    assert_equal ['archive_is', 'archive_org'].sort, Media.enabled_archivers('archive_is', 'archive_org').keys
    Media::ARCHIVERS['archive_org'][:enabled] = false
    assert_equal ['archive_is'].sort, Media.enabled_archivers('archive_is', 'archive_org').keys
    Media::ARCHIVERS['archive_org'][:enabled] = true
  end

  test "should archive to perma.cc and store the URL on archives" do
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://twitter.com/meedan/status/1095755205554200576'
    m = Media.new url: url, key: a
    m.as_json

    Media.any_instance.unstub(:archive_to_perma_cc)
    Pender::Store.stubs(:read).returns(nil)
    response = 'mock';response.stubs(:code).returns('201');response.stubs(:body).returns('{"guid":"AUA8-QNGH"}')
    Net::HTTP.any_instance.stubs(:request).returns(response)
    Media.stubs(:notify_webhook_and_update_cache).with('perma_cc', url, { location: 'http://perma.cc/AUA8-QNGH'}, a.id)
    Media.stubs(:enabled_archivers).with('perma_cc').returns({ 'perma_cc' => {:patterns=>[/^.*$/], :modifier=>:only, :enabled=>true}})

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

  test "should update media with error when archive to Perma.cc fails" do
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
      assert_equal({"message"=>I18n.t(:could_not_archive, error_message: 'Unauthorized'), "code"=>"401"}, media_data.dig('archives', 'perma_cc', 'error'))
    end

    WebMock.disable!
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_canonical_url)
    Media.any_instance.unstub(:try_https)
    Media.any_instance.unstub(:parse)
    Media.any_instance.unstub(:archive)
  end

  test "should not declare Perma.cc as archiver if perma_key is not present" do
    assert_nil CONFIG.dig('perma_cc_key')
    assert_not_includes Media::ARCHIVERS.keys, 'perma_cc'
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

  test "should call youtube-dl and worker to upload video when archive video" do
    Sidekiq::Testing.fake!
    Media.any_instance.unstub(:archive_to_video)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://twitter.com/meedan/status/1202732707597307905'
    m = Media.new url: url, key: a
    m.as_json

    Media.any_instance.unstub(:archive_to_video)
    Media.stubs(:supported_video?).with(url).returns(true)
    Media.stubs(:notify_video_already_archived).with(url, a.id).returns(nil)

    assert_difference 'ArchiveVideoWorker.jobs.size', 1 do
      Media.archive_video(url, a.id)
    end

    not_video_url = 'https://twitter.com/meedan/status/1214263820484521985'
    Media.stubs(:supported_video?).with(not_video_url).returns(true)
    Media.stubs(:notify_video_already_archived).with(not_video_url, a.id).returns(nil)

    assert_no_difference 'ArchiveVideoWorker.jobs.size' do
      Media.archive_video(not_video_url, a.id)
    end

    Media.unstub(:supported_video?)
    Media.unstub(:notify_video_already_archived)

    ArchiveVideoWorker.clear
  end

  test "should return false when is not supported when archive video" do
    assert Media.supported_video?('https://twitter.com/meedan/status/1202732707597307905')

    assert !Media.supported_video?('https://twitter.com/meedan/status/1214263820484521985')
  end

  test "should notify if URL was already parsed and has a location on data when archive video" do
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://twitter.com/meedan/status/1202732707597307905'

    Pender::Store.stubs(:read).with(Media.get_id(url), :json).returns(nil)
    assert_nil Media.notify_video_already_archived(url, nil)

    data = { archives: { video_archiver: { error: 'could not download video data'}}}
    Pender::Store.stubs(:read).with(Media.get_id(url), :json).returns()
    assert_nil Media.notify_video_already_archived(url, nil)

    data[:archives][:video_archiver] = { location: 'path_to_video' }
    Pender::Store.stubs(:read).with(Media.get_id(url), :json).returns(data)
    Media.stubs(:notify_webhook).with('video_archiver', url, data, {}).returns('Notify webhook')
    assert_equal 'Notify webhook', Media.notify_video_already_archived(url, nil)

    Pender::Store.unstub(:read)
    Media.unstub(:notify_webhook)
  end

  test "should archive video and update cache" do
    Sidekiq::Testing.fake!
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://twitter.com/meedan/status/1202732707597307905'
    id = Media.get_id url

    assert_equal 0, ArchiveVideoWorker.jobs.size
    m = create_media url: url, key: a
    data = m.as_json
    assert_nil data.dig('archives', 'video_archiver')
    Media.archive_video(url, a.id)
    assert_equal 1, ArchiveVideoWorker.jobs.size

    ArchiveVideoWorker.drain
    data = m.as_json
    assert_nil data.dig('archives', 'video_archiver', 'error', 'message')
    assert_equal "#{File.join(Media.archiving_folder, id)}/#{id}.mp4", data.dig('archives', 'video_archiver', 'location')
  end

  test "should archive video info subtitles and thumbnails" do
    Sidekiq::Testing.fake!
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://www.youtube.com/watch?v=1vSJrexmVWU'
    id = Media.get_id url

    assert_equal 0, ArchiveVideoWorker.jobs.size
    m = create_media url: url, key: a
    data = m.as_json
    assert_nil data.dig('archives', 'video_archiver')
    Media.archive_video(url, a.id)
    assert_equal 1, ArchiveVideoWorker.jobs.size

    ArchiveVideoWorker.drain
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
  end

  test "should handle error and update cache when archiving fails" do
    Sidekiq::Testing.fake!
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://twitter.com/meedan/status/1202732707597307905'
    id = Media.get_id url

    assert_equal 0, ArchiveVideoWorker.jobs.size
    m = create_media url: url, key: a
    data = m.as_json
    assert_nil data.dig('archives', 'video_archiver')
    Media.archive_video(url, a.id)
    assert_equal 1, ArchiveVideoWorker.jobs.size

    Pender::Store.stubs(:upload_video_folder).raises(StandardError.new('upload error'))
    ArchiveVideoWorker.drain
    data = m.as_json
    assert_not_nil data.dig('archives', 'video_archiver', 'error', 'message')
    Pender::Store.unstub(:upload_video_folder)
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
end
