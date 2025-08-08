require 'test_helper'

class ArchiverTest < ActiveSupport::TestCase
  def setup
    WebMock.enable!
    WebMock.disable_net_connect!(allow: [/minio/])
    Sidekiq::Testing.inline!
    clear_bucket
  end

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

  # I don't really understand what this test is doing
  test "should skip screenshots" do
    stub_configs({'archiver_skip_hosts' => '' })

    api_key = create_api_key

    url = 'https://checkmedia.org/caio-screenshots/project/1121/media/8390'
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    m = create_media url: url, key: api_key
    data = m.process_and_return_json

    stub_configs({'archiver_skip_hosts' => 'checkmedia.org' })

    url = 'https://checkmedia.org/caio-screenshots/project/1121/media/8390?hide_tasks=1'
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    m = create_media url: url, key: api_key
    data = m.process_and_return_json
  end

  test "should archive to Archive.org" do
    api_key = create_api_key_with_webhook
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_archive_org)

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return_json(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' })
    WebMock.stub_request(:get, /archive.org\/wayback/).to_return_json(body: {"archived_snapshots":{}}, headers: {})
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return_json(body: {status: 'success', timestamp: 'timestamp'})

    media = create_media url: url, key: api_key
    data = media.process_and_return_json(archivers: 'archive_org')

    assert_equal "https://web.archive.org/web/timestamp/#{url}", data.dig('archives', 'archive_org', 'location')
  end

  test "should log archiver information when archiving URLs" do
    api_key = create_api_key_with_webhook
    url = 'https://example.com/'
    log = StringIO.new
    Rails.logger = Logger.new(log)

    Media.any_instance.unstub(:archive_to_archive_org)


    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return_json(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' })
    WebMock.stub_request(:get, /archive.org\/wayback/).to_return_json(body: {"archived_snapshots":{}}, headers: {})
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return_json(body: {status: 'success', timestamp: 'timestamp'})

    media = create_media url: url, key: api_key
    media.process_and_return_json(archivers: 'archive_org')

    assert_match '[Archiver] Archiving new URL', log.string
    assert_match url, log.string
  end

  test "should archive Arabics url to Archive.org" do
    api_key = create_api_key_with_webhook
    url = 'https://www.yallakora.com/ar/news/342470/%D8%A7%D8%AA%D8%AD%D8%A7%D8%AF-%D8%A7%D9%84%D9%83%D8%B1%D8%A9-%D8%B9%D9%86-%D8%A3%D8%B2%D9%85%D8%A9-%D8%A7%D9%84%D8%B3%D8%B9%D9%8A%D8%AF-%D9%84%D8%A7%D8%A8%D8%AF-%D9%85%D9%86-%D8%AD%D9%84-%D9%85%D8%B9-%D8%A7%D9%84%D8%B2%D9%85%D8%A7%D9%84%D9%83/2504'

    Media.any_instance.unstub(:archive_to_archive_org)

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>صفحة باللغة العربية</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return_json(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' })
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return_json(body: {status: 'success', timestamp: 'timestamp'})

    assert_nothing_raised do
      m = create_media url: url, key: api_key
      m.process_and_return_json
    end
  end

  test "should archive to Perma.cc" do
    api_key = create_api_key_with_webhook_for_perma_cc
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_perma_cc)

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:post, /api.perma.cc/).to_return_json(body: { guid: 'perma-cc-guid' })

    media = create_media url: url, key: api_key
    data = media.process_and_return_json(archivers: 'perma_cc')

    assert_equal "http://perma.cc/perma-cc-guid", data.dig('archives', 'perma_cc', 'location')
  end

  test "should update media with error when Archive.org can't archive the url" do
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
      m.process_and_return_json(archivers: 'none')
      assert_nil m.data.dig('archives', 'archive_org')

      WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
      WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
      WebMock.stub_request(:post, /web.archive.org\/save/).to_return_json(body: { status: 'error', status_ext: data[:status_ext], message: data[:message] })
      WebMock.stub_request(:get, /archive.org\/wayback/).to_return(body: { "archived_snapshots": {} }.to_json, headers: {})

      assert_raises StandardError do
        Media.send_to_archive_org(url.to_s, api_key.id)
      end
      media_data = Pender::Store.current.read(Media.cache_key(url), :json)
      assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_ERROR'), media_data.dig('archives', 'archive_org', 'error', 'code')
      assert_equal "(#{data[:status_ext]}) #{data[:message]}", media_data.dig('archives', 'archive_org', 'error', 'message')
      end
  end

  test "when Archive.org fails with Pender::Exception::ArchiveOrgError it should not notify Sentry, it should retry, update data with snapshot (if available) and error" do
    api_key = create_api_key_with_webhook
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_archive_org)
    Media.stubs(:get_available_archive_org_snapshot).returns({ location: "https://web.archive.org/web/timestamp/#{url}" })

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return_json(status: 500, body: { status_ext: '500', message: 'Random Error.', url: url})

    sentry_call_count = 0
    arguments_checker = Proc.new do |e|
      sentry_call_count += 1
    end

    media = create_media url: url, key: api_key
    PenderSentry.stub(:notify, arguments_checker) do
      assert_raises StandardError do
        media.process_and_return_json(archivers: 'archive_org')
      end
    end

    assert_equal 0, sentry_call_count
    media_data = Pender::Store.current.read(Media.cache_key(url), :json)
    assert_equal '(500) Random Error.', media_data.dig('archives', 'archive_org', 'error', 'message')
    assert_equal "https://web.archive.org/web/timestamp/#{url}", media_data.dig('archives', 'archive_org', 'location')
  end

  test "when Archive.org fails with the same snapshot has been made... it should NOT retry, and should notify Sentry" do
    api_key = create_api_key_with_webhook
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_archive_org)
    Media.stubs(:get_available_archive_org_snapshot).returns({ message: 'The same snapshot had been made 1 hour, 12 minutes ago. You can make new capture of this URL after 24 hours.', url: url })

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return_json(status: 200, body: { message: 'The same snapshot had been made 1 hour, 12 minutes ago. You can make new capture of this URL after 24 hours.', url: url})

    m = Media.new url: url, key: api_key

    sentry_call_count = 0
    arguments_checker = Proc.new do |e|
      sentry_call_count += 1
    end

    PenderSentry.stub(:notify, arguments_checker) do
      assert_nothing_raised do
        m.process_and_return_json(archivers: 'archive_org')
      end
    end
    assert_equal 1, sentry_call_count

    media_data = Pender::Store.current.read(Media.cache_key(url), :json)
    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_ERROR'), media_data.dig('archives', 'archive_org', 'error', 'code')
  end

  test "when Archive.org fails with too-many-daily-captures it should NOT retry, and should notify Sentry" do
    api_key = create_api_key_with_webhook
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_archive_org)
    Media.stubs(:get_available_archive_org_snapshot).returns({ status_ext: 'error:too-many-daily-captures', message: 'This URL has been already captured 7 times today, which is a daily limit we have set for that Resource type. Please try again tomorrow. Please email us at "info@archive.org" if you would like to discuss this more.', url: url })

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return_json(status: 200, body: { status_ext: 'error:too-many-daily-captures', message: 'This URL has been already captured 7 times today, which is a daily limit we have set for that Resource type. Please try again tomorrow. Please email us at "info@archive.org" if you would like to discuss this more.', url: url})

    m = Media.new url: url, key: api_key

    sentry_call_count = 0
    arguments_checker = Proc.new do |e|
      sentry_call_count += 1
    end

    PenderSentry.stub(:notify, arguments_checker) do
      assert_nothing_raised do
        m.process_and_return_json(archivers: 'archive_org')
      end
    end
    assert_equal 1, sentry_call_count

    media_data = Pender::Store.current.read(Media.cache_key(url), :json)
    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_ERROR'), media_data.dig('archives', 'archive_org', 'error', 'code')
  end

  test "when Archive.org fails with blocked-url it should NOT retry, and should notify Sentry" do
    api_key = create_api_key_with_webhook
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_archive_org)
    Media.stubs(:get_available_archive_org_snapshot).returns({ status_ext: 'error:blocked-url', message: 'This URL is in the Save Page Now service block list and cannot be captured.', url: url })

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return_json(status: 200, body: { status: 'error', status_ext: 'error:blocked-url', message: 'This URL is in the Save Page Now service block list and cannot be captured.', url: url })

    m = Media.new url: url, key: api_key

    sentry_call_count = 0
    arguments_checker = Proc.new do |e|
      sentry_call_count += 1
    end

    PenderSentry.stub(:notify, arguments_checker) do
      assert_nothing_raised do
        m.process_and_return_json(archivers: 'archive_org')
      end
    end
    assert_equal 1, sentry_call_count

    media_data = Pender::Store.current.read(Media.cache_key(url), :json)
    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_ERROR'), media_data.dig('archives', 'archive_org', 'error', 'code')
  end

  test "when Archive.org fails to make/complete a request it should retry and update data with error" do
    api_key = create_api_key_with_webhook
    url = 'https://meedan.com/post/annual-report-2022'

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:any, /archive.org/).to_raise(Net::ReadTimeout.new('Exception from WebMock'))
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    m = create_media url: url, key: api_key
    assert_raises StandardError do
      data = m.process_and_return_json(archivers: 'archive_org')
      assert_nil data.dig('archives', 'archive_org')
    end

    data = m.process_and_return_json
    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_ERROR'), data.dig('archives', 'archive_org', 'error', 'code')
    assert_equal 'Net::ReadTimeout with "Exception from WebMock"', data.dig('archives', 'archive_org', 'error', 'message')
  end

  test "when Perma.cc fails with Pender::Exception::PermaCcError it should update media with error and retry" do
    api_key = create_api_key_with_webhook_for_perma_cc
    url = 'https://example.com'

    Media.any_instance.unstub(:archive_to_perma_cc)
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:post, /api.perma.cc/).to_return(status: [400, 'Bad Request'], body: { 'error': "A random error." }.to_json)

    m = Media.new url: url, key: api_key
    assert_raises StandardError do
      m.process_and_return_json(archivers: 'perma_cc')
    end
    media_data = Pender::Store.current.read(Media.cache_key(url), :json)
    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_ERROR'), media_data.dig('archives', 'perma_cc', 'error', 'code')
    assert_equal '(400) Bad Request', media_data.dig('archives', 'perma_cc', 'error', 'message')
  end

  test "when Perma.cc fails with Pender::Exception::TooManyCaptures it should update media with error and not retry" do
    api_key = create_api_key_with_webhook_for_perma_cc
    url = 'https://example.com'

    Media.any_instance.unstub(:archive_to_perma_cc)
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:post, /api.perma.cc/).to_return(status: [400, 'Bad Request'], body: { 'error': "Perma can't create this link. You've reached your usage limit. Visit your Usage Plan page for information and plan options." }.to_json)

    m = Media.new url: url, key: api_key
    assert_nothing_raised do
      m.process_and_return_json(archivers: 'perma_cc')
    end

    media_data = Pender::Store.current.read(Media.cache_key(url), :json)
    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_ERROR'), media_data.dig('archives', 'perma_cc', 'error', 'code')
    assert_equal '(400) Bad Request', media_data.dig('archives', 'perma_cc', 'error', 'message')
  end

  test "when Perma.cc fails to make/complete a request it should retry and update data with error" do
    api_key = create_api_key_with_webhook_for_perma_cc
    url = 'https://meedan.com/post/annual-report-2022'

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:post, /api.perma.cc/).to_raise(Net::ReadTimeout.new('Exception from WebMock'))

    m = create_media url: url, key: api_key
    assert_raises StandardError do
      data = m.process_and_return_json(archivers: 'perma_cc')
      assert_nil data.dig('archives', 'perma_cc')
    end

    data = m.process_and_return_json
    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_ERROR'), data.dig('archives', 'perma_cc', 'error', 'code')
    assert_equal 'Net::ReadTimeout with "Exception from WebMock"', data.dig('archives', 'perma_cc', 'error', 'message')
  end

  test "should update media with error when archive to Archive.org hits the limit of retries" do
    api_key = create_api_key_with_webhook
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_archive_org)
    Media.stubs(:get_available_archive_org_snapshot).returns({ location: "https://web.archive.org/web/timestamp/#{url}" })

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return_json(status: 500, body: { status_ext: '500', message: 'Random Error.', url: url})

    media = Media.new url: url, key: api_key
    assert_raises StandardError do
      media.process_and_return_json(archivers: 'archive_org')
    end
    Media.give_up({ args: [url, 'archive_org', api_key], error_message: 'Gave Up', error_class: 'error class'})

    media_data = Pender::Store.current.read(Media.cache_key(url), :json)
    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_FAILURE'), media_data.dig('archives', 'archive_org', 'error', 'code')
    assert_equal "Gave Up", media_data.dig('archives', 'archive_org', 'error', 'message')
  end

  test "if a refresh is not requested and archive is present in cache should not archive on Archive.org" do
    url = 'https://example.com/'
    api_key = create_api_key_with_webhook

    Media.any_instance.unstub(:archive_to_archive_org)
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')

    m = Media.new url: url, key: api_key
    id = Media.cache_key(m.url)

    WebMock.stub_request(:get, /archive.org\/wayback/).to_return(body: {"archived_snapshots":{}}.to_json, headers: {})
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return_json(body: {url: 'archive_org/first_archiving', job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' })
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return_json(body: {status: 'success', timestamp: 'archive-timestamp-FIRST'})
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    m.process_and_return_json(archivers: 'archive_org')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['archive_org'], cached.keys
    assert_equal({ 'location' => 'https://web.archive.org/web/archive-timestamp-FIRST/https://example.com/'}, cached['archive_org'])

    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return_json(body: {status: 'success', timestamp: 'archive-timestamp-SECOND'})
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    m.process_and_return_json(archivers: 'archive_org')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['archive_org'], cached.keys
    assert_equal({ 'location' => 'https://web.archive.org/web/archive-timestamp-FIRST/https://example.com/'}, cached['archive_org'])
  end

  test "if a refresh is requested it should try to archive on Archive.org" do
    url = 'https://example.com/'
    api_key = create_api_key_with_webhook

    Media.any_instance.unstub(:archive_to_archive_org)
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')

    m = Media.new url: url, key: api_key
    id = Media.cache_key(m.url)

    WebMock.stub_request(:get, /archive.org\/wayback/).to_return(body: {"archived_snapshots":{}}.to_json, headers: {})
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return_json(body: {url: 'archive_org/first_archiving', job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' })
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return_json(body: {status: 'success', timestamp: 'archive-timestamp-FIRST'})
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    m.process_and_return_json(archivers: 'archive_org')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['archive_org'], cached.keys
    assert_equal({ 'location' => 'https://web.archive.org/web/archive-timestamp-FIRST/https://example.com/'}, cached['archive_org'])

    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return_json(body: {status: 'success', timestamp: 'archive-timestamp-SECOND'})
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    m.process_and_return_json(force: true, archivers: 'archive_org')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['archive_org'], cached.keys
    assert_equal({ 'location' => 'https://web.archive.org/web/archive-timestamp-SECOND/https://example.com/'}, cached['archive_org'])
  end

  test "if a refresh is not requested and archive is present in cache it should not try to archive on Perma.cc" do
    url = 'https://example.com'
    api_key = create_api_key_with_webhook_for_perma_cc

    Media.any_instance.unstub(:archive_to_perma_cc)
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A Page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')

    m = Media.new url: url, key: api_key
    id = Media.cache_key(m.url)

    WebMock.stub_request(:post, /api.perma.cc/).to_return_json(body: { guid: 'perma-cc-guid-FIRST' })
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    m.process_and_return_json(archivers: 'perma_cc')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['perma_cc'], cached.keys
    assert_equal({ 'location' => 'http://perma.cc/perma-cc-guid-FIRST'}, cached['perma_cc'])

    WebMock.stub_request(:post, /api.perma.cc/).to_return_json(body: { guid: 'perma-cc-guid-SECOND' })

    m.process_and_return_json(archivers: 'perma_cc')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['perma_cc'], cached.keys
    assert_equal({ 'location' => 'http://perma.cc/perma-cc-guid-FIRST'}, cached['perma_cc'])
  end

  test "if a refresh is requested it should try to create a new archive on Perma.cc" do
    url = 'https://example.com'
    api_key = create_api_key_with_webhook_for_perma_cc

    Media.any_instance.unstub(:archive_to_perma_cc)
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A Page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')

    m = Media.new url: url, key: api_key
    id = Media.cache_key(m.url)

    Media.any_instance.unstub(:archive_to_perma_cc)
    WebMock.stub_request(:post, /api.perma.cc/).to_return_json(body: { guid: 'perma-cc-guid-FIRST' })
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    m.process_and_return_json(archivers: 'perma_cc')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['perma_cc'], cached.keys
    assert_equal({ 'location' => 'http://perma.cc/perma-cc-guid-FIRST'}, cached['perma_cc'])

    WebMock.stub_request(:post, /api.perma.cc/).to_return_json(body: { guid: 'perma-cc-guid-SECOND' })

    m.process_and_return_json(force: true, archivers: 'perma_cc')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['perma_cc'], cached.keys
    assert_equal({ 'location' => 'http://perma.cc/perma-cc-guid-SECOND'}, cached['perma_cc'])
  end

  test "should not archive in any archiver if none is requested" do
    api_key = create_api_key_with_webhook
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_archive_org)

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:get, /archive.org\/wayback/).to_return(body: {"archived_snapshots":{}}.to_json, headers: {})
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return_json(body: {url: 'archive_org/first_archiving', job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' })
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return_json(body: {status: 'success', timestamp: 'archive-timestamp'})
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    id = Media.cache_key(url)
    m = create_media url: url, key: api_key
    m.process_and_return_json
    assert_equal({}, Pender::Store.current.read(id, :json)[:archives])

    m.process_and_return_json(archivers: '')
    assert_equal({}, Pender::Store.current.read(id, :json)[:archives])

    m.process_and_return_json(archivers: nil)
    assert_equal({}, Pender::Store.current.read(id, :json)[:archives])

    m.process_and_return_json(archivers: 'none')
    assert_equal({}, Pender::Store.current.read(id, :json)[:archives])

    m.process_and_return_json(archivers: 'archive_org')
    assert_equal({'archive_org' => {"location" => 'https://web.archive.org/web/archive-timestamp/https://example.com/'}}, Pender::Store.current.read(id, :json)[:archives])
  end

  test "should update cache when a new archiver is requested without the need to request for a refresh" do
    api_key = create_api_key_with_webhook_for_perma_cc
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_perma_cc)
    Media.any_instance.unstub(:archive_to_archive_org)

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /api.perma.cc/).to_return_json(body: { guid: 'perma-cc-guid-1' })
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    id = Media.cache_key(url)
    m = create_media url: url, key: api_key
    m.process_and_return_json(archivers: 'perma_cc')
    assert_equal({'perma_cc' => {"location" => 'http://perma.cc/perma-cc-guid-1'}}, Pender::Store.current.read(id, :json)[:archives])

    WebMock.stub_request(:get, /archive.org\/wayback/).to_return(body: {"archived_snapshots":{}}.to_json, headers: {})
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return_json(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' })
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return_json(body: {status: 'success', timestamp: 'timestamp'})

    m.process_and_return_json(archivers: 'perma_cc, archive_org')
    assert_equal({'perma_cc' => {'location' => 'http://perma.cc/perma-cc-guid-1'}, 'archive_org' => {'location' => "https://web.archive.org/web/timestamp/#{url}" }}, Pender::Store.current.read(id, :json)[:archives])
  end

  test "should not archive again if media on cache has both archivers" do
    api_key = create_api_key_with_webhook_for_perma_cc
    url = 'https://fakewebsite.com/'

    Media.any_instance.unstub(:archive_to_archive_org)
    Media.any_instance.unstub(:archive_to_perma_cc)
    Media.stubs(:get_available_archive_org_snapshot).returns(nil)

    # Our webhook response
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    # A fake website that never redirects us, so that our Media.cache_key stays consistent
    WebMock.stub_request(:get, /fakewebsite.com/).to_return(status: 200, body: '')

    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')

    # First archiver request responses
    WebMock.stub_request(:post, /api.perma.cc/).to_return_json(body: { guid: 'perma-cc-guid-1' })
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return_json(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' })
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return_json(body: {status: 'success', timestamp: 'timestamp'})

    id = Media.cache_key(url)
    m = create_media url: url, key: api_key
    m.process_and_return_json(archivers: 'perma_cc, archive_org')
    assert_equal({'perma_cc' => {'location' => 'http://perma.cc/perma-cc-guid-1'}, 'archive_org' => {'location' => "https://web.archive.org/web/timestamp/#{url}" }}, Pender::Store.current.read(id, :json)[:archives])

    # Second archiver request responses
    WebMock.stub_request(:post, /api.perma.cc/).to_return_json(body: { guid: 'perma-cc-guid-2' })
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return_json(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' })
    WebMock.stub_request(:get, /web.archive.org\/save\/status/).to_return_json(body: {status: 'success', timestamp: 'timestamp2'})

    m.process_and_return_json
    assert_equal({'location' => 'http://perma.cc/perma-cc-guid-1'}, Pender::Store.current.read(id, :json)[:archives][:perma_cc])
    assert_equal({'location' => "https://web.archive.org/web/timestamp/#{url}" }, Pender::Store.current.read(id, :json)[:archives][:archive_org])

    m.process_and_return_json(archivers: 'none')
    assert_equal({'location' => 'http://perma.cc/perma-cc-guid-1'}, Pender::Store.current.read(id, :json)[:archives][:perma_cc])
    assert_equal({'location' => "https://web.archive.org/web/timestamp/#{url}" }, Pender::Store.current.read(id, :json)[:archives][:archive_org])
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
    api_key = create_api_key_with_webhook_for_perma_cc
    url = 'https://example.com'

    Media.any_instance.unstub(:archive_to_perma_cc)
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A Page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /api.perma.cc/).to_return_json(body: { guid: 'perma-cc-guid-1' })
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    m = Media.new url: url, key: api_key
    id = Media.cache_key(m.url)
    m.process_and_return_json(archivers: 'perma_cc')

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['perma_cc'], cached.keys
    assert_equal({ 'location' => 'http://perma.cc/perma-cc-guid-1'}, cached['perma_cc'])
  end

  test "should add disabled Perma.cc archiver error message if perma_key is not defined" do
    api_key = create_api_key_with_webhook
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_perma_cc)
    Media.stubs(:available_archivers).returns(['perma_cc'])
    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A Page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, "https://example.com/webhook.php").to_return(status: 200, body: '')

    m = Media.new url: url, key: api_key
    m.process_and_return_json(archivers: 'perma_cc')

    id = Media.cache_key(url)
    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_match 'missing authentication', cached.dig('perma_cc', 'error', 'message').downcase
    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_MISSING_KEY'), cached.dig('perma_cc', 'error', 'code')
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

  test "include error on data when cannot use archiver" do
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
  end

  test "should get and return the available snapshot if page was already archived on Archive.org" do
    url = 'https://example.com/'
    api_key = create_api_key_with_webhook

    url = 'https://example.com/'
    api_key = create_api_key application_settings: { 'webhook_url': 'https://example.com/webhook.php', 'webhook_token': 'test' }
    encoded_uri = RequestHelper.encode_url(url)

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A Page</html>')
    WebMock.stub_request(:get, /archive.org\/wayback\/available?.+url=#{url}/).to_return_json(body: {"archived_snapshots":{ closest: { available: true, url: 'http://web.archive.org/web/20210223111252/http://example.com/' }}})
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')

    snapshot = Media.get_available_archive_org_snapshot(encoded_uri, api_key)
    assert_equal 'http://web.archive.org/web/20210223111252/http://example.com/' , snapshot[:location]
  end

  test "should return nil if page was not previously archived on Archive.org" do
    url = 'https://example.com/'

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A Page</html>')
    WebMock.stub_request(:get, /archive.org\/wayback/).to_return_json(body: {"archived_snapshots":{}})

    assert_nil Media.get_available_archive_org_snapshot(url, nil)
  end

  test "should still cache data if notifying webhook fails" do
    api_key = create_api_key_with_webhook_for_perma_cc
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_perma_cc)

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A Page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /api.perma.cc/).to_return_json(body: { guid: 'perma-cc-guid-1' })
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 425, body: '')

    m = Media.new url: url, key: api_key
    id = Media.cache_key(m.url)
    assert_raises Pender::Exception::RetryLater do
      m.process_and_return_json(archivers: 'perma_cc')
    end

    cached = Pender::Store.current.read(id, :json)[:archives]
    assert_equal ['perma_cc'], cached.keys
    assert_equal({ 'location' => 'http://perma.cc/perma-cc-guid-1'}, cached['perma_cc'])
  end

  test "when Archive.org status returns 429 Too Many Requests it should notify Sentry with RateLimitExceeded" do
    api_key = create_api_key_with_webhook
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_archive_org)

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    # This response comes from ArchiveStatusJob, in order to call it we need to get a job_id
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return_json(body: {url: url, job_id: 'ebb13d31-7fcf-4dce-890c-c256e2823ca0' })
    WebMock.stub_request(:get, /archive.org\/wayback/).to_return_json(body: {"archived_snapshots":{}}, headers: {})
    WebMock.stub_request(:get, /archive.org\/save\/status/).to_return(body:  '429 Too Many Requests')

    m = Media.new url: url, key: api_key

    sentry_call_count = 0
    arguments_checker = Proc.new do |e|
      sentry_call_count += 1
      assert_instance_of Pender::Exception::RateLimitExceeded, e
      assert_includes e.message, 'Too Many Requests'
    end

    PenderSentry.stub(:notify, arguments_checker) do
      assert_nothing_raised do
        m.process_and_return_json(archivers: 'archive_org')
      end
    end

    assert_equal 1, sentry_call_count

    media_data = Pender::Store.current.read(Media.cache_key(url), :json)
    expected_error_message = "Too Many Requests"
    assert_includes media_data.dig('archives', 'archive_org', 'error', 'message'), expected_error_message
    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_ERROR'), media_data.dig('archives', 'archive_org', 'error', 'code')
  end

  test "when Archive.org returns HTML response it should notify Sentry with JSON::ParserError" do
    api_key = create_api_key_with_webhook
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_archive_org)

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return_json(body: '<html>A html response</html>' )
    WebMock.stub_request(:get, /archive.org\/wayback/).to_return_json(body: {"archived_snapshots":{}}, headers: {})

    m = Media.new url: url, key: api_key

    sentry_call_count = 0
    arguments_checker = Proc.new do |e|
      sentry_call_count += 1
      assert_instance_of JSON::ParserError, e
    end

    PenderSentry.stub(:notify, arguments_checker) do
      assert_nothing_raised do
        m.process_and_return_json(archivers: 'archive_org')
      end
    end

    assert_equal 1, sentry_call_count

    media_data = Pender::Store.current.read(Media.cache_key(url), :json)
    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_ERROR'), media_data.dig('archives', 'archive_org', 'error', 'code')
  end

  test "when Archive.org returns 'Item Not Available' response it should notify Sentry with Pender::Exception::ItemNotAvailable" do
    api_key = create_api_key_with_webhook
    url = 'https://example.com/'

    Media.any_instance.unstub(:archive_to_archive_org)

    WebMock.stub_request(:get, url).to_return(status: 200, body: '<html>A page</html>')
    WebMock.stub_request(:post, /safebrowsing\.googleapis\.com/).to_return(status: 200, body: '{}')
    WebMock.stub_request(:post, /example.com\/webhook/).to_return(status: 200, body: '')
    WebMock.stub_request(:post, /web.archive.org\/save/).to_return_json(body: 'Item Not Available' )
    WebMock.stub_request(:get, /archive.org\/wayback/).to_return_json(body: {"archived_snapshots":{}}, headers: {})

    m = Media.new url: url, key: api_key

    sentry_call_count = 0
    arguments_checker = Proc.new do |e|
      sentry_call_count += 1
      assert_instance_of Pender::Exception::ItemNotAvailable, e
      assert_includes e.message, 'Item Not Available'
    end

    PenderSentry.stub(:notify, arguments_checker) do
      assert_nothing_raised do
        m.process_and_return_json(archivers: 'archive_org')
      end
    end

    assert_equal 1, sentry_call_count

    media_data = Pender::Store.current.read(Media.cache_key(url), :json)
    expected_error_message = "Item Not Available"
    assert_includes media_data.dig('archives', 'archive_org', 'error', 'message'), expected_error_message
    assert_equal Lapis::ErrorCodes::const_get('ARCHIVER_ERROR'), media_data.dig('archives', 'archive_org', 'error', 'code')
  end
end
