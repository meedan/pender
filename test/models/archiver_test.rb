require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class ArchiverTest < ActiveSupport::TestCase

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

  test "should archive to Video Vault" do
    config = CONFIG['video_vault_token']
    CONFIG['video_vault_token'] = '123456'

    Media.any_instance.unstub(:archive_to_video_vault)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    url = 'https://twitter.com/marcouza/status/875424957613920256'
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'www.bravenewtech.org' }
    WebMock.disable_net_connect!(allow: allowed_sites)
    WebMock.stub_request(:any, 'https://www.bravenewtech.org/api/').to_return(body: { status: 203, package: '123456' }.to_json)
    WebMock.stub_request(:any, 'https://www.bravenewtech.org/api/status.php').to_return(body: { location: 'http://videovault/123456' }.to_json)

    assert_nothing_raised do
      m = create_media url: url, key: a
      data = m.as_json
    end

    CONFIG['video_vault_token'] = config
    WebMock.disable!
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

    assert_raises RuntimeError do
      WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '')
      m = create_media url: urls[2], key: a
      data = m.as_json
    end

    WebMock.disable!
  end

  test "should archive to Archive.org" do
    Media.any_instance.unstub(:archive_to_archive_org)
    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    urls = ['https://twitter.com/marcouza/status/875424957613920256', 'https://twitter.com/marcouza/status/863907872421412864']
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'web.archive.org' }
    WebMock.disable_net_connect!(allow: allowed_sites)

    assert_nothing_raised do
      WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: {})
      m = create_media url: urls[0], key: a
      data = m.as_json

      WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/web/123456/test' })
      m = create_media url: urls[1], key: a
      data = m.as_json
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

    Airbrake.configuration.stubs(:api_key).returns('token')
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
        id = Media.get_id(url)
        media_data = Rails.cache.read(id)
        assert_equal({"message"=>I18n.t(:could_not_archive, error_message: data[:message]), "code"=>data[:code]}, media_data.dig('archives', 'archive_org', 'error'))
      end
    end

    WebMock.disable!
    Airbrake.configuration.unstub(:api_key)
    Airbrake.unstub(:notify)
    Media.any_instance.unstub(:follow_redirections)
    Media.any_instance.unstub(:get_canonical_url)
    Media.any_instance.unstub(:try_https)
    Media.any_instance.unstub(:parse)
    Media.any_instance.unstub(:archive)
  end

  test "should raise error and update media when unexpected response from Archive.is" do
    WebMock.enable!
    allowed_sites = lambda{ |uri| uri.host != 'archive.is' }
    WebMock.disable_net_connect!(allow: allowed_sites)
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:parse)
    Media.any_instance.stubs(:archive)

    Airbrake.configuration.stubs(:api_key).returns('token')
    Airbrake.stubs(:notify)

    a = create_api_key application_settings: { 'webhook_url': 'http://ca.ios.ba/files/meedan/webhook.php', 'webhook_token': 'test' }
    urls = ['http://www.unexistent-page.html', 'http://localhost:3333/unreachable-url']

    urls.each do |url|
      assert_raise RuntimeError do
        m = Media.new url: url
        m.as_json
        assert m.data.dig('archives', 'archive_is').nil?
        WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', status: ['200', 'OK'], headers: {})
        Media.send_to_archive_is(url.to_s, a.id, 20)
        id = Media.get_id(url)
        media_data = Rails.cache.read(id)
        assert_equal({"message"=>I18n.t(:could_not_archive, error_message: data[:message]), "code"=>data[:code]}, media_data.dig('archives', 'archive_is', 'error'))
      end
    end

    WebMock.disable!
    Airbrake.configuration.unstub(:api_key)
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

    Airbrake.configuration.stubs(:api_key).returns('token')
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
        id = Media.get_id(url)
        media_data = Rails.cache.read(id)
        assert_equal({"message"=>I18n.t(:could_not_archive, error_message: data[:message]), "code"=>data[:code]}, media_data.dig('archives', 'archive_is', 'error'))
      end
    end

    WebMock.disable!
    Airbrake.configuration.unstub(:api_key)
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
    assert_equal({"archive_is"=>{"location"=>"http://archive.is/test"}, "archive_org"=>{"location"=>"https://web.archive.org/web/123456/test"}}, Rails.cache.read(id)[:archives])
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
    assert_equal({}, Rails.cache.read(id)[:archives])
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
      cached = Rails.cache.read(id)[:archives]
      assert_equal(archivers, cached.keys)
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
    assert_equal({'archive_is' => {"location" => 'archive_is/first_archiving'}}, Rails.cache.read(id)[:archives])

    WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { location: 'archive_is/second_archiving' })
    WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/archiving' })
    m.as_json(force: true, archivers: 'archive_is, archive_org')
    assert_equal({'archive_is' => {'location' => 'archive_is/second_archiving'}, 'archive_org' => {'location' => 'https://web.archive.org/archiving' }}, Rails.cache.read(id)[:archives])
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
    assert_equal({'archive_is' => {"location" => 'archive_is/first_archiving'}}, Rails.cache.read(id)[:archives])

    WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { location: 'archive_is/second_archiving' })
    WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/archiving' })
    m.as_json(archivers: 'archive_is, archive_org')
    assert_equal({'archive_is' => {'location' => 'archive_is/first_archiving'}, 'archive_org' => {'location' => 'https://web.archive.org/archiving' }}, Rails.cache.read(id)[:archives])
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
    assert_equal({'archive_is' => {'location' => 'archive_is/first_archiving'}, 'archive_org' => {'location' => 'https://web.archive.org/archiving' }}, Rails.cache.read(id)[:archives])

    WebMock.stub_request(:any, 'http://archive.is/submit/').to_return(body: '', headers: { location: 'archive_is/second_archiving' })
    WebMock.stub_request(:any, /web.archive.org/).to_return(body: '', headers: { 'content-location' => '/second_archiving' })

    m.as_json
    assert_equal({'archive_is' => {'location' => 'archive_is/first_archiving'}, 'archive_org' => {'location' => 'https://web.archive.org/archiving' }}, Rails.cache.read(id)[:archives])

    m.as_json(archivers: 'none')
    assert_equal({'archive_is' => {'location' => 'archive_is/first_archiving'}, 'archive_org' => {'location' => 'https://web.archive.org/archiving' }}, Rails.cache.read(id)[:archives])

    WebMock.disable!
  end

end
