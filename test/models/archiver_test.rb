require 'test_helper'

class ArchiverTest < ActiveSupport::TestCase
  def teardown
    isolated_teardown
  end

  def quietly_redefine_constant(klass, constant, new_value)
    original_verbosity = $VERBOSE
    $VERBOSE = nil

    klass.const_set(constant, new_value)

    $VERBOSE = original_verbosity
  end

  def create_api_key_with_webhook
    create_api_key application_settings: { 'webhook_url': 'https://example.com/webhook.php', 'webhook_token': 'test' }
  end

  def create_api_key_with_webhook_for_perma_cc
    create_api_key application_settings: { config: { 'perma_cc_key': 'my-perma-key' }, 'webhook_url': 'https://example.com/webhook.php', 'webhook_token': 'test' }
  end

  test "should skip screenshots" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    stub_configs({'archiver_skip_hosts' => '' })

    api_key = create_api_key

    url = 'https://checkmedia.org/caio-screenshots/project/1121/media/8390'
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    id = Media.get_id(url)
    m = create_media url: url, key: api_key
    data = m.as_json

    stub_configs({'archiver_skip_hosts' => 'checkmedia.org' })

    url = 'https://checkmedia.org/caio-screenshots/project/1121/media/8390?hide_tasks=1'
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    id = Media.get_id(url)
    m = create_media url: url, key: api_key
    data = m.as_json
  ensure
    WebMock.disable!
  end

  test "should archive to Archive.org" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    api_key = create_api_key_with_webhook
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_archive_org)

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' }.to_json)
    WebMock.stub_request(:get, /archive.org\/wayback/).to_return(body: {"archived_snapshots":{}}.to_json, headers: {})
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'success', timestamp: 'timestamp'}.to_json)

    media = create_media url: url, key: api_key
    data = media.as_json(archivers: 'archive_org')

    assert_equal "https://web.archive.org/web/timestamp/#{url}", data.dig('archives', 'archive_org', 'location') 
  ensure
    WebMock.disable!
  end
  
  test "should archive Arabics url to Archive.org" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    api_key = create_api_key_with_webhook
    url = 'https://www.yallakora.com/ar/news/342470/%D8%A7%D8%AA%D8%AD%D8%A7%D8%AF-%D8%A7%D9%84%D9%83%D8%B1%D8%A9-%D8%B9%D9%86-%D8%A3%D8%B2%D9%85%D8%A9-%D8%A7%D9%84%D8%B3%D8%B9%D9%8A%D8%AF-%D9%84%D8%A7%D8%A8%D8%AF-%D9%85%D9%86-%D8%AD%D9%84-%D9%85%D8%B9-%D8%A7%D9%84%D8%B2%D9%85%D8%A7%D9%84%D9%83/2504'

    Media.any_instance.unstub(:archive_to_archive_org)

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>صفحة باللغة العربية</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' }.to_json)
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'success', timestamp: 'timestamp'}.to_json)

    assert_nothing_raised do
      m = create_media url: url, key: api_key
      data = m.as_json
    end
  ensure
    WebMock.disable!
  end

  test "should archive to Perma.cc" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    api_key = create_api_key_with_webhook_for_perma_cc
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_perma_cc)

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:any, /api.perma.cc/).to_return(body: { guid: 'perma-cc-guid' }.to_json)

    media = create_media url: url, key: api_key
    data = media.as_json(archivers: 'perma_cc')

    assert_equal "http://perma.cc/perma-cc-guid", data.dig('archives', 'perma_cc', 'location') 
  ensure
    WebMock.disable!
  end

  test "when archive.org fails to archive, it should add to data the available archive.org snapshot (if available) and the error" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    api_key = create_api_key_with_webhook
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_archive_org)
    Media.stubs(:get_available_archive_org_snapshot).returns({ location: "https://web.archive.org/web/timestamp/#{url}" })

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return(status: 200, body: { message: 'The same snapshot had been made 12 hours, 13 minutes ago. You can make new capture of this URL after 24 hours.', url: url}.to_json)

    media = create_media url: url, key: api_key
    data = media.as_json(archivers: 'archive_org')
    
    id = Media.get_id(media.url)
    cached = Pender::Store.current.read(id, :json)[:archives]

    assert_match /The same snapshot/, data.dig('archives', 'archive_org', 'error', 'message') 
    assert_equal "https://web.archive.org/web/timestamp/#{url}", data.dig('archives', 'archive_org', 'location') 
  ensure
    WebMock.disable!
  end

  test "should update media with error when Archive.org can't archive the url" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    api_key = create_api_key_with_webhook
    urls = {
      'http://localhost:3333/unreachable-url' => {status_ext: 'error:invalid-url-syntax', message: 'URL syntax is not valid'},
      'http://www.dutertenewsupdate.info/2018/01/duterte-turned-philippines-into.html' => {status_ext: 'error:invalid-host-resolution', message: 'Cannot resolve host'},
    }

    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:parse)
    Media.any_instance.stubs(:archive)

    urls.each_pair do |url, data|
      m = Media.new url: url
      m.as_json(archivers: 'none')
      assert_nil m.data.dig('archives', 'archive_org')

      WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
      WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
      WebMock.stub_request(:any, /web.archive.org\/save/).to_return(body: {status: 'error', status_ext: data[:status_ext], message: data[:message]}.to_json)
      WebMock.stub_request(:get, /archive.org\/wayback/).to_return(body: {"archived_snapshots":{}}.to_json, headers: {})

      assert_raises Pender::Exception::RetryLater do
        Media.send_to_archive_org(url.to_s, api_key.id)
      end
      media_data = Pender::Store.current.read(Media.get_id(url), :json)
      assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_ERROR'), media_data.dig('archives', 'archive_org', 'error', 'code')
      assert_equal "(#{data[:status_ext]}) #{data[:message]}", media_data.dig('archives', 'archive_org', 'error', 'message')
      end
  ensure
    WebMock.disable!
  end

  test "should update media with error when archive to Perma.cc fails" do
    skip('fix this')
    WebMock.enable!
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:parse)
    Media.any_instance.stubs(:archive)

    a = create_api_key application_settings: { config: { 'perma_cc_key': 'my-perma-key' }, 'webhook_url': 'https://example.com/webhook.php', 'webhook_token': 'test' }
    url = 'http://example.com'

    assert_raises Pender::Exception::RetryLater do
      m = Media.new url: url, key: a
      m.as_json
      assert m.data.dig('archives', 'perma_cc').nil?
      Media.send_to_perma_cc(url.to_s, a.id, 20)
      media_data = Pender::Store.current.read(Media.get_id(url), :json)
      assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_FAILURE'), media_data.dig('archives', 'perma_cc', 'error', 'code')
      assert_equal "401 Unauthorized", media_data.dig('archives', 'perma_cc', 'error', 'message')
    end
  ensure
    WebMock.disable!
  end

  test "should update media with error when archive to Archive.org fails too many times" do
    skip('fix this')
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    api_key = create_api_key_with_webhook
    url = 'https://example.com/'

    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:parse)
    Media.any_instance.stubs(:archive)

    m = Media.new url: url
    m.as_json(archivers: 'none')
    assert_nil m.data.dig('archives', 'archive_org')

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0'}.to_json)
    WebMock.stub_request(:get, /archive.org\/wayback/).to_return(body: {"archived_snapshots":{}}.to_json, headers: {})
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'error', status_ext: 'error:not-found', message: 'The server cannot find the requested resource'}.to_json)

    assert_raises Pender::Exception::RetryLater do
      Media.send_to_archive_org(url.to_s, api_key.id)
    end
      media_data = Pender::Store.current.read(Media.get_id(url), :json)
      assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_FAILURE'), media_data.dig('archives', 'archive_org', 'error', 'code')
      assert_equal "#{data[:code]} #{data[:message]}", media_data.dig('archives', 'archive_org', 'error', 'message')
  ensure
    WebMock.disable!
  end

  test "if a refresh is not requested and archive is present in cache should not archive on Archive.org" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    url = 'https://example.com/'
    api_key = create_api_key_with_webhook

    Media.any_instance.unstub(:archive_to_archive_org)
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')

    m = Media.new url: url, key: api_key
    id = Media.get_id(m.url)

    WebMock.stub_request(:get, /archive.org\/wayback/).to_return(body: {"archived_snapshots":{}}.to_json, headers: {})
    WebMock.stub_request(:any, /web.archive.org\/save/).to_return(body: {url: 'archive_org/first_archiving', job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' }.to_json)
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'success', timestamp: 'archive-timestamp-FIRST'}.to_json)
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    m.as_json(archivers: 'archive_org')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['archive_org'], cached.keys
    assert_equal({ 'location' => 'https://web.archive.org/web/archive-timestamp-FIRST/https://example.com/'}, cached['archive_org'])

    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'success', timestamp: 'archive-timestamp-SECOND'}.to_json)
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    m.as_json(archivers: 'archive_org')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['archive_org'], cached.keys
    assert_equal({ 'location' => 'https://web.archive.org/web/archive-timestamp-FIRST/https://example.com/'}, cached['archive_org'])
  ensure
    WebMock.disable!
  end

  test "if a refresh is requested it should try to archive on Archive.org" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    url = 'https://example.com/'
    api_key = create_api_key_with_webhook
    
    Media.any_instance.unstub(:archive_to_archive_org)
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')

    m = Media.new url: url, key: api_key
    id = Media.get_id(m.url)

    WebMock.stub_request(:get, /archive.org\/wayback/).to_return(body: {"archived_snapshots":{}}.to_json, headers: {})
    WebMock.stub_request(:any, /web.archive.org\/save/).to_return(body: {url: 'archive_org/first_archiving', job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' }.to_json)
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'success', timestamp: 'archive-timestamp-FIRST'}.to_json)
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    m.as_json(archivers: 'archive_org')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['archive_org'], cached.keys
    assert_equal({ 'location' => 'https://web.archive.org/web/archive-timestamp-FIRST/https://example.com/'}, cached['archive_org'])

    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'success', timestamp: 'archive-timestamp-SECOND'}.to_json)
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    m.as_json(force: true, archivers: 'archive_org')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['archive_org'], cached.keys
    assert_equal({ 'location' => 'https://web.archive.org/web/archive-timestamp-SECOND/https://example.com/'}, cached['archive_org'])
  ensure
    WebMock.disable!
  end

  test "if a refresh is not requested and archive is present in cache it should not try to archive on Perma.cc" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    url = 'https://example.com'
    api_key = create_api_key_with_webhook_for_perma_cc

    Media.any_instance.unstub(:archive_to_perma_cc)
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A Page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')

    m = Media.new url: url, key: api_key
    id = Media.get_id(m.url)

    WebMock.stub_request(:any, /api.perma.cc/).to_return(body: { guid: 'perma-cc-guid-FIRST' }.to_json)
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    m.as_json(archivers: 'perma_cc')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['perma_cc'], cached.keys
    assert_equal({ 'location' => 'http://perma.cc/perma-cc-guid-FIRST'}, cached['perma_cc'])

    WebMock.stub_request(:any, /api.perma.cc/).to_return(body: { guid: 'perma-cc-guid-SECOND' }.to_json)

    m.as_json(archivers: 'perma_cc')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['perma_cc'], cached.keys
    assert_equal({ 'location' => 'http://perma.cc/perma-cc-guid-FIRST'}, cached['perma_cc'])
  ensure
    WebMock.disable!
  end

  test "if a refresh is requested it should try to archive on Perma.cc" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    url = 'https://example.com'
    api_key = create_api_key_with_webhook_for_perma_cc

    Media.any_instance.unstub(:archive_to_perma_cc)
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A Page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')

    m = Media.new url: url, key: api_key
    id = Media.get_id(m.url)

    Media.any_instance.unstub(:archive_to_perma_cc)
    WebMock.stub_request(:any, /api.perma.cc/).to_return(body: { guid: 'perma-cc-guid-FIRST' }.to_json)
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    m.as_json(archivers: 'perma_cc')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['perma_cc'], cached.keys
    assert_equal({ 'location' => 'http://perma.cc/perma-cc-guid-FIRST'}, cached['perma_cc'])

    WebMock.stub_request(:any, /api.perma.cc/).to_return(body: { guid: 'perma-cc-guid-SECOND' }.to_json)

    m.as_json(force: true, archivers: 'perma_cc')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['perma_cc'], cached.keys
    assert_equal({ 'location' => 'http://perma.cc/perma-cc-guid-SECOND'}, cached['perma_cc'])
  ensure
    WebMock.disable!
  end

  test "should not archive in any archiver if none is requested" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    api_key = create_api_key_with_webhook
    url = 'https://example.com/'
    
    Media.any_instance.unstub(:archive_to_archive_org)

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:get, /archive.org\/wayback/).to_return(body: {"archived_snapshots":{}}.to_json, headers: {})
    WebMock.stub_request(:any, /web.archive.org\/save/).to_return(body: {url: 'archive_org/first_archiving', job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' }.to_json)
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'success', timestamp: 'archive-timestamp'}.to_json)
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    id = Media.get_id(url)
    m = create_media url: url, key: api_key
    m.as_json
    assert_equal({}, Pender::Store.current.read(id, :json)[:archives])

    m.as_json(archivers: '')
    assert_equal({}, Pender::Store.current.read(id, :json)[:archives])

    m.as_json(archivers: nil)
    assert_equal({}, Pender::Store.current.read(id, :json)[:archives])

    m.as_json(archivers: 'none')
    assert_equal({}, Pender::Store.current.read(id, :json)[:archives])

    m.as_json(archivers: 'archive_org')
    assert_equal({'archive_org' => {"location" => 'https://web.archive.org/web/archive-timestamp/https://example.com/'}}, Pender::Store.current.read(id, :json)[:archives])
  ensure
    WebMock.disable!
  end

  test "should update cache when a new archiver is requested without the need to request for a refresh" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    api_key = create_api_key_with_webhook_for_perma_cc
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_perma_cc)
    Media.any_instance.unstub(:archive_to_archive_org)

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:any, /api.perma.cc/).to_return(body: { guid: 'perma-cc-guid-1' }.to_json)
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    id = Media.get_id(url)
    m = create_media url: url, key: api_key
    m.as_json(archivers: 'perma_cc')
    assert_equal({'perma_cc' => {"location" => 'http://perma.cc/perma-cc-guid-1'}}, Pender::Store.current.read(id, :json)[:archives])

    WebMock.stub_request(:get, /archive.org\/wayback/).to_return(body: {"archived_snapshots":{}}.to_json, headers: {})
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' }.to_json)
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'success', timestamp: 'timestamp'}.to_json)

    m.as_json(archivers: 'perma_cc, archive_org')
    assert_equal({'perma_cc' => {'location' => 'http://perma.cc/perma-cc-guid-1'}, 'archive_org' => {'location' => "https://web.archive.org/web/timestamp/#{url}" }}, Pender::Store.current.read(id, :json)[:archives])
  ensure
    WebMock.disable!
  end

  test "should not archive again if media on cache has both archivers" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    api_key = create_api_key_with_webhook_for_perma_cc
    url = 'https://fakewebsite.com/'
    
    Media.any_instance.unstub(:archive_to_archive_org)
    Media.any_instance.unstub(:archive_to_perma_cc)
    Media.stubs(:get_available_archive_org_snapshot).returns(nil)

    # Our webhook response
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    # A fake website that never redirects us, so that our Media.get_id stays consistent
    WebMock.stub_request(:get, /fakewebsite.com/).to_return(status: 200, body: '')

    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')

    # First archiver request responses
    WebMock.stub_request(:any, /api.perma.cc/).to_return(body: { guid: 'perma-cc-guid-1' }.to_json)
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' }.to_json)
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'success', timestamp: 'timestamp'}.to_json)

    id = Media.get_id(url)
    m = create_media url: url, key: api_key
    m.as_json(archivers: 'perma_cc, archive_org')
    assert_equal({'perma_cc' => {'location' => 'http://perma.cc/perma-cc-guid-1'}, 'archive_org' => {'location' => "https://web.archive.org/web/timestamp/#{url}" }}, Pender::Store.current.read(id, :json)[:archives])

    # Second archiver request responses
    WebMock.stub_request(:any, /api.perma.cc/).to_return(body: { guid: 'perma-cc-guid-2' }.to_json)
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' }.to_json)
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return(body: {status: 'success', timestamp: 'timestamp2'}.to_json)

    m.as_json
    assert_equal({'location' => 'http://perma.cc/perma-cc-guid-1'}, Pender::Store.current.read(id, :json)[:archives][:perma_cc])
    assert_equal({'location' => "https://web.archive.org/web/timestamp/#{url}" }, Pender::Store.current.read(id, :json)[:archives][:archive_org])

    m.as_json(archivers: 'none')
    assert_equal({'location' => 'http://perma.cc/perma-cc-guid-1'}, Pender::Store.current.read(id, :json)[:archives][:perma_cc])
    assert_equal({'location' => "https://web.archive.org/web/timestamp/#{url}" }, Pender::Store.current.read(id, :json)[:archives][:archive_org])
  ensure
    WebMock.disable!
  end

  test "return the enabled archivers" do
    enabled_archivers = Media::ENABLED_ARCHIVERS
    Media.const_set(:ENABLED_ARCHIVERS, [{key: 'archive_org'}, {key: 'perma_cc'}])

    assert_equal ['archive_org', 'perma_cc'].sort, Media.enabled_archivers(['archive_org', 'perma_cc']).keys

    quietly_redefine_constant(Media, :ENABLED_ARCHIVERS, [{key: 'archive_org'}])

    assert_equal ['archive_org'].sort, Media.enabled_archivers(['perma_cc', 'archive_org']).keys
  ensure
    quietly_redefine_constant(Media, :ENABLED_ARCHIVERS, enabled_archivers)
  end

  test "should archive to perma.cc and store the URL on archives if perma_cc_key is present" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    api_key = create_api_key_with_webhook_for_perma_cc
    url = 'https://example.com'
    
    Media.any_instance.unstub(:archive_to_perma_cc)
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A Page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:any, /api.perma.cc/).to_return(body: { guid: 'perma-cc-guid-1' }.to_json)
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    m = Media.new url: url, key: api_key
    id = Media.get_id(m.url)
    m.as_json(archivers: 'perma_cc')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['perma_cc'], cached.keys
    assert_equal({ 'location' => 'http://perma.cc/perma-cc-guid-1'}, cached['perma_cc'])
  ensure
    WebMock.disable!
  end

  test "should add disabled Perma.cc archiver error message if perma_key is not present" do
    skip('fix this')
    WebMock.enable!
    url = 'https://example.com/'

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A Page</html>')
    Media.any_instance.unstub(:archive_to_perma_cc)
    Media.stubs(:available_archivers).returns(['perma_cc'])

    id = Media.get_id(url)

    assert_raises Pender::Exception::RetryLater do
      m = Media.new url: url, key: nil
      m.as_json(archivers: 'perma_cc')
    end
    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_match 'missing authentication', cached.dig('perma_cc', 'error', 'message').downcase
    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_MISSING_KEY'), cached.dig('perma_cc', 'error', 'code')
  ensure
    WebMock.disable!
  end

  test "should return api key settings" do
    key1 = create_api_key application_settings: {'webhook_url': 'https://example.com/webhook.php', 'webhook_token': 'test' }
    key2 = create_api_key application_settings: {}
    key3 = create_api_key
    [key1.id, key2.id, key3.id, -1].each do |id|
      assert_nothing_raised do
        Media.api_key_settings(id)
      end
    end
  end

  test "should call youtube-dl and call video upload when archive video" do
    skip('we are not supporting archiving videos with youtube-dl anymore, will remove this on a separate ticket')
    WebMock.enable!
    api_key = create_api_key_with_webhook
    url = 'https://www.bbc.com/news/av/world-us-canada-57176620'

    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    Media.any_instance.unstub(:archive_to_video)

    m = Media.new url: url, key: api_key
    m.as_json

    Media.stubs(:supported_video?).with(m.url, api_key.id).returns(true)
    Media.stubs(:notify_video_already_archived).with(m.url, api_key.id).returns(nil)

    Media.stubs(:store_video_folder).returns('store_video_folder')
    Media.stubs(:system).returns(`(exit 0)`)
    assert_equal 'store_video_folder', Media.send_to_video_archiver(m.url, api_key.id)
    assert_nil Media.send_to_video_archiver(m.url, api_key.id, false)
  ensure
    WebMock.disable!
  end

  test "should return false and add error to data when video archiving is not supported" do
    skip('we are not supporting archiving videos with youtube-dl anymore, will remove this on a separate ticket')
    WebMock.enable!
    api_key = create_api_key_with_webhook
    
    Media.unstub(:supported_video?)
    Media.any_instance.stubs(:parse)
    Metrics.stubs(:schedule_fetching_metrics_from_facebook)
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    
    Media.stubs(:system).returns(`(exit 0)`)
    url = 'https://www.folha.uol.com.br/'
    m = create_media url: url
    m.as_json(archivers: 'none')
    assert Media.supported_video?(m.url, api_key.id)

    media_data = Pender::Store.current.read(Media.get_id(url), :json)
    assert_nil media_data.dig('archives', 'video_archiver')

    Media.stubs(:system).returns(`(exit 1)`)
    url = 'https://www.r7.com/'
    m = create_media url: url
    m.as_json(archivers: 'none')
    assert !Media.supported_video?(m.url, api_key.id)

    media_data = Pender::Store.current.read(Media.get_id(url), :json)
    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_NOT_SUPPORTED_MEDIA'), media_data.dig('archives', 'video_archiver', 'error', 'code')
    assert_equal '1 Unsupported URL', media_data.dig('archives', 'video_archiver', 'error', 'message')
  ensure
    WebMock.disable!
  end

  test "should check if non-ascii URL support video download" do
    skip('we are not supporting archiving videos with youtube-dl anymore, will remove this on a separate ticket')
    Media.unstub(:supported_video?)
    assert !Media.supported_video?('http://example.com/pages/category/Musician-Band/चौधरी-कमला-बाड़मेर-108960273957085')
  end

  test "should notify if URL was already parsed and has a location on data when archive video" do
    skip('we are not supporting archiving videos with youtube-dl anymore, will remove this on a separate ticket')
    WebMock.enable!
    api_key = create_api_key_with_webhook
    url = 'https://www.bbc.com/news/av/world-us-canada-57176620'

    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

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
  ensure
    WebMock.disable!
  end

  # FIXME Mocking Youtube-DL to avoid `HTTP Error 429: Too Many Requests`
  test "should archive video info subtitles, thumbnails and update cache" do
    skip('we are not supporting archiving videos with youtube-dl anymore, will remove this on a separate ticket')
    WebMock.enable!
    
    api_key = create_api_key_with_webhook
    url = 'https://www.youtube.com/watch?v=1vSJrexmVWU'
    id = Media.get_id url
    
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    Media.stubs(:supported_video?).with(url, api_key.id).returns(true)
    Media.stubs(:system).returns(`(exit 0)`)
    local_folder = File.join(Rails.root, 'tmp', 'videos', id)
    video_files = "#{local_folder}/#{id}/#{id}.es.vtt", "#{local_folder}/#{id}/#{id}.jpg", "#{local_folder}/#{id}/#{id}.vtt", "#{local_folder}/#{id}/#{id}.mp4", "#{local_folder}/#{id}/#{id}.jpg", "#{local_folder}/#{id}/#{id}.info.json"
    Dir.stubs(:glob).returns(video_files)
    Pender::Store.any_instance.stubs(:upload_video_folder)

    m = create_media url: url, key: api_key
    data = m.as_json
    assert_nil data.dig('archives', 'video_archiver')
    Media.send_to_video_archiver(url, api_key.id, 20)

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
  ensure
    WebMock.disable!
  end

  test "should raise retry error when video archiving fails" do
    skip('we are not supporting archiving videos with youtube-dl anymore, will remove this on a separate ticket')
    WebMock.enable!
    Sidekiq::Testing.fake!
    api_key = create_api_key_with_webhook
    url = 'https://www.wsj.com/'

    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    Media.stubs(:supported_video?).with(url, api_key.id).returns(true)
    id = Media.get_id url
    m = create_media url: url, key: api_key
    data = m.as_json
    assert_nil data.dig('archives', 'video_archiver')

    Media.stubs(:system).returns(`(exit 1)`)
    not_video_url = 'https://www.uol.com.br/'
    Media.stubs(:supported_video?).with(not_video_url, api_key.id).returns(true)
    Media.stubs(:notify_video_already_archived).with(not_video_url, api_key.id).returns(nil)

    Media.stubs(:system).returns(`(exit 1)`)
    assert_raises Pender::Exception::RetryLater do
      Media.send_to_video_archiver(not_video_url, api_key.id)
    end
  ensure
    WebMock.disable!
  end

  test "should update media with error when supported video call raises on video archiving" do
    skip('we are not supporting archiving videos with youtube-dl anymore, will remove this on a separate ticket')
    WebMock.enable!
    Sidekiq::Testing.fake!
    api_key = create_api_key_with_webhook
    url = 'https://example.com'

    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:parse)
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    assert_raises Pender::Exception::RetryLater do
      m = Media.new url: url
      data = m.as_json
      assert m.data.dig('archives', 'video_archiver').nil?
      error = StandardError.new('some error')
      Media.stubs(:supported_video?).with(url, api_key.id).raises(error)
      Media.send_to_video_archiver(url, api_key.id, 20)
      media_data = Pender::Store.current.read(Media.get_id(url), :json)
      assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_ERROR'), media_data.dig('archives', 'video_archiver', 'error', 'code')
      assert_equal "#{error.class} #{error.message}", media_data.dig('archives', 'video_archiver', 'error', 'message')
    end
  ensure
    WebMock.disable!
  end

  test "should update media with error when video download fails when video archiving" do
    skip('we are not supporting archiving videos with youtube-dl anymore, will remove this on a separate ticket')
    WebMock.enable!
    api_key = create_api_key_with_webhook
    url = 'https://www.tiktok.com/@scout2015/video/6771039287917038854'

    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)
    Media.any_instance.stubs(:parse)
    Media.stubs(:supported_video?).returns(true)
    Media.stubs(:system).returns(`(exit 1)`)

    assert_raises Pender::Exception::RetryLater do
      m = Media.new url: url
      data = m.as_json(archivers: 'none')
      assert_nil m.data.dig('archives', 'video_archiver')
      Media.send_to_video_archiver(url, api_key.id, 20)
      media_data = Pender::Store.current.read(Media.get_id(url), :json)
      assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_FAILURE'), media_data.dig('archives', 'video_archiver', 'error', 'code')
      assert_match 'not available', media_data.dig('archives', 'video_archiver', 'error', 'message').downcase
    end
  ensure
    WebMock.disable!
  end

  test "should generate the public archiving folder for videos" do
    skip('we are not supporting archiving videos with youtube-dl anymore, will remove this on a separate ticket')
    api_key = create_api_key application_settings: { config: { storage_endpoint: 'http://minio:9000', storage_bucket: 'default-bucket', storage_video_asset_path: nil, storage_video_bucket: nil }}
    ApiKey.current = api_key

    assert_match /#{PenderConfig.get('storage_endpoint')}\/default-bucket\d*\/video/, Media.archiving_folder

    api_key.application_settings[:config][:storage_video_bucket] = 'bucket-for-videos'; api_key.save
    ApiKey.current = api_key
    Pender::Store.current = nil
    PenderConfig.current = nil
    assert_match /#{PenderConfig.get('storage_endpoint')}\/bucket-for-videos\d*\/video/, Media.archiving_folder

    api_key.application_settings[:config][:storage_video_asset_path] = 'http://public-storage/my-videos'; api_key.save
    ApiKey.current = api_key
    Pender::Store.current = nil
    PenderConfig.current = nil
    assert_equal "http://public-storage/my-videos", Media.archiving_folder
  end

  test "should send to video archiver when call archive to video" do
    skip('we are not supporting archiving videos with youtube-dl anymore, will remove this on a separate ticket')
    Media.any_instance.unstub(:archive_to_video)
    Media.any_instance.stubs(:follow_redirections)
    Media.any_instance.stubs(:get_canonical_url).returns(true)
    Media.any_instance.stubs(:try_https)

    Sidekiq::Testing.fake! do
      url = 'http://example.com'
      m = Media.new url: url
      assert_difference 'ArchiverWorker.jobs.size', 1 do
        m.archive_to_video(m.url, nil)
      end
    end
  end

  test "should get proxy to download video from api key if present" do
    skip('we are not supporting archiving videos with youtube-dl anymore, will remove this on a separate ticket')
    WebMock.enable!
    api_key = create_api_key application_settings: { 'webhook_url': 'https://example.com/webhook.php', 'webhook_token': 'test' }
    url = 'https://www.youtube.com/watch?v=unv9aPZYF6E'

    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    m = Media.new url: url, key: api_key

    assert_nil Media.yt_download_proxy(m.url)

    api_key.application_settings = { config: { ytdl_proxy_host: 'my-proxy.mine', ytdl_proxy_port: '1111', ytdl_proxy_user_prefix: 'my-user-prefix', ytdl_proxy_pass: '12345' }}; api_key.save
    PenderConfig.current = nil
    m = Media.new url: url, key: api_key
    assert_equal 'http://my-user-prefix:12345@my-proxy.mine:1111', Media.yt_download_proxy(m.url)
  ensure
    WebMock.disable!
  end

  test "should use api key config when archiving video if present" do
    skip('we are not supporting archiving videos with youtube-dl anymore, will remove this on a separate ticket')
    WebMock.enable!
    api_key = create_api_key application_settings: { 'webhook_url': 'https://example.com/webhook.php', 'webhook_token': 'test' }
    url = 'https://www.youtube.com/watch?v=o1V1LnUU5VM'

    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    Media.unstub(:supported_video?)
    Media.stubs(:system).returns(`(exit 0)`)

    config = {}
    %w(ytdl_proxy_host ytdl_proxy_port ytdl_proxy_user_prefix ytdl_proxy_pass storage_endpoint storage_access_key storage_secret_key storage_bucket storage_bucket_region storage_video_bucket).each do |config_key|
      config[config_key] = PenderConfig.get(config_key, "test_#{config_key}")
    end

    ApiKey.current = PenderConfig.current = Pender::Store.current = nil
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
  ensure
    WebMock.disable!
  end

  test "include error on data when cannot use archiver" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    skip = ENV['archiver_skip_hosts']
    ENV['archiver_skip_hosts'] = 'example.com'

    url = 'https://example.com'
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A Page</html>')

    m = Media.new url: url
    m.data = Media.minimal_data(m)

    m.archive('archive_org')
    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_HOST_SKIPPED'), m.data.dig('archives', 'archive_org', 'error', 'code')
    assert_match 'Host Skipped: example.com', m.data.dig('archives', 'archive_org', 'error', 'message')
    ENV['archiver_skip_hosts'] = ''

    PenderConfig.reload
    enabled = Media::ENABLED_ARCHIVERS
    Media.const_set(:ENABLED_ARCHIVERS, [])

    m.archive('archive_org,unexistent_archive')

    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_NOT_FOUND'), m.data.dig('archives', 'unexistent_archive', 'error', 'code')
    assert_match 'Not Found', m.data.dig('archives', 'unexistent_archive', 'error', 'message')
    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_DISABLED'), m.data.dig('archives', 'archive_org', 'error', 'code')
    assert_match 'Disabled', m.data.dig('archives', 'archive_org', 'error', 'message')
  ensure
    quietly_redefine_constant(Media, :ENABLED_ARCHIVERS, enabled)
    ENV['archiver_skip_hosts'] = skip
    WebMock.disable!
  end

  test "should get and return the available snapshot if page was already archived on Archive.org" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    url = 'https://example.com/'
    api_key = create_api_key_with_webhook

    url = 'https://example.com/'
    api_key = create_api_key application_settings: { 'webhook_url': 'https://example.com/webhook.php', 'webhook_token': 'test' }
    encoded_uri = RequestHelper.encode_url(url)

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A Page</html>')
    WebMock.stub_request(:get, /archive.org\/wayback\/available?.+url=#{url}/).to_return(body: {"archived_snapshots":{ closest: { available: true, url: 'http://web.archive.org/web/20210223111252/http://example.com/' }}}.to_json)
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    snapshot = Media.get_available_archive_org_snapshot(encoded_uri, api_key)
    assert_equal 'http://web.archive.org/web/20210223111252/http://example.com/' , snapshot[:location]
  ensure
    WebMock.disable!
  end

  test "should return nil if page was not previously archived on Archive.org" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    url = 'https://example.com/'

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A Page</html>')
    WebMock.stub_request(:get, /archive.org\/wayback/).to_return(body: {"archived_snapshots":{}}.to_json)

    assert_nil Media.get_available_archive_org_snapshot(url, nil)
  ensure
    WebMock.disable!
  end

  test "should still cache data if notifying webhook fails" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    api_key = create_api_key_with_webhook_for_perma_cc
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_perma_cc)

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A Page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /api.perma.cc/).to_return(body: { guid: 'perma-cc-guid-1' }.to_json)
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 425, body: '')

    m = Media.new url: url, key: api_key
    id = Media.get_id(m.url)
    assert_raises Pender::Exception::RetryLater do
      m.as_json(archivers: 'perma_cc')
    end

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['perma_cc'], cached.keys
    assert_equal({ 'location' => 'http://perma.cc/perma-cc-guid-1'}, cached['perma_cc'])
  ensure
    WebMock.disable!
  end
end
