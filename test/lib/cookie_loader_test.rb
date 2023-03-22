require 'test_helper'
require_relative '../../lib/cookie_loader'

class CookieLoaderTest < ActiveSupport::TestCase
  def cookie_contents
    <<~STRING
      # HTTP Cookie File downloaded with cookies.txt by Genuinous @genuinous
      # This file can be used by wget, curl, aria2c and other standard compliant tools.
      # Usage Examples:
      #   1) wget -x --load-cookies cookies.txt "https://www.washingtonpost.com/politics/winter-is-coming-allies-fear-trump-isnt-prepared-for-gathering-legal-storm/2018/08/29/b07fc0a6-aba0-11e8-b1da-ff7faa680710_story.html?utm_term=.520dc8c63ae1"
      #   2) curl --cookie cookies.txt "https://www.washingtonpost.com/politics/winter-is-coming-allies-fear-trump-isnt-prepared-for-gathering-legal-storm/2018/08/29/b07fc0a6-aba0-11e8-b1da-ff7faa680710_story.html?utm_term=.520dc8c63ae1"
      #   3) aria2c --load-cookies cookies.txt "https://www.washingtonpost.com/politics/winter-is-coming-allies-fear-trump-isnt-prepared-for-gathering-legal-storm/2018/08/29/b07fc0a6-aba0-11e8-b1da-ff7faa680710_story.html?utm_term=.520dc8c63ae1"
      #
      # .ignoredurl.com	TRUE	/	FALSE	1234567890	sessionid	555
      .example.com	TRUE	/	FALSE	1538248063	wp_devicetype	0
      .anotherexample.com	TRUE	/	FALSE	1538248063	piglet	dog
    STRING
  end

  def cookies_file
    return @cookies_file if @cookies_file
    @cookies_file = Tempfile.new('fake-cookies.txt')
    @cookies_file.write(cookie_contents)
    @cookies_file.rewind
    @cookies_file
  end

  def setup
    isolated_setup

    # We're currently loading the application before running these tests,
    # which calls CookieLoader as part of initialization. Because of that
    # we'll want to make sure and check existing state before setting our expectations
    # and limit the scope of any mocks.
    @existing_cookies = CONFIG['cookies']
    CONFIG['cookies'] = nil
  end

  def teardown
    isolated_teardown
    CONFIG['cookies'] = @existing_cookies
  end

  # Success cases:
  test 'loads cookies into CONFIG from local file system if local filepath provided, ignoring commented lines' do
    assert PenderConfig.get('cookies').blank?

    CookieLoader.load_from(cookies_file.path)
    PenderConfig.load('cookies')

    cookies = PenderConfig.get('cookies')
    assert_equal 2, cookies.length
    assert_equal cookies['.example.com']['wp_devicetype'], '0'
    assert_equal cookies['.anotherexample.com']['piglet'], 'dog'
  ensure
    cookies_file.close
    cookies_file.unlink
  end

  test 'requests file from S3 if file path begins S3 and loads result into config' do
    mocked_cookie_response = MiniTest::Mock.new
    def mocked_cookie_response.successful?; true; end

    mocked_s3_client = MiniTest::Mock.new
    mocked_s3_client.expect(:get_object, mocked_cookie_response) do |args|
      File.open(args[:response_target], 'w') { |file| file.write(cookie_contents) }
      args[:bucket] == 'fake-bucket' && args[:key] == 'fake-cookies.txt' && args[:response_target].present?
    end

    Aws::S3::Client.stub(:new, mocked_s3_client) do
      CookieLoader.load_from('s3://fake-bucket/fake-cookies.txt')

      mocked_s3_client.verify
    end

    PenderConfig.load('cookies')
    cookies = PenderConfig.get('cookies')
    assert_equal 2, cookies.length
    assert_equal cookies['.example.com']['wp_devicetype'], '0'
    assert_equal cookies['.anotherexample.com']['piglet'], 'dog'
  end

  # Error cases:
  test 'keeps cookies as empty and reports error if file path not provided' do
    mocked_sentry = MiniTest::Mock.new
    mocked_sentry.expect :call, :return_value do |error, args|
      error.class.to_s.match(/FilePathError/) &&
        error.message.match(/Path not provided/) &&
        args[:provided_path].nil?
    end

    PenderSentry.stub(:notify, mocked_sentry) do
      CookieLoader.load_from(nil)
      mocked_sentry.verify
    end

    PenderConfig.load('cookies')
    assert_equal PenderConfig.get('cookies'), {}
  end

  test 'keeps cookies as empty and reports error if file path does not exist' do
    mocked_sentry = MiniTest::Mock.new
    mocked_sentry.expect :call, :return_value do |error, args|
      error.class.to_s.match(/FilePathError/) &&
        error.message.match(/No file found at path/) &&
        args[:provided_path] == 'totally/fake/path.txt'
    end

    PenderSentry.stub(:notify, mocked_sentry) do
      CookieLoader.load_from("totally/fake/path.txt")
      mocked_sentry.verify
    end

    PenderConfig.load('cookies')
    assert_equal PenderConfig.get('cookies'), {}
  end

  test 'keeps cookies as empty and reports problem downloading from S3' do
    mocked_sentry = MiniTest::Mock.new
    mocked_sentry.expect :call, :return_value do |error, args|
      error.class.to_s.match(/S3DownloadError/) &&
        error.message.match(/Unsuccessful response from S3/) &&
        args[:provided_path] == 's3://fake-bucket/fake-cookies.txt'
    end

    Aws::S3::Client.any_instance.stubs(:get_object).returns(OpenStruct.new(successful?: false))

    PenderSentry.stub(:notify, mocked_sentry) do
      CookieLoader.load_from("s3://fake-bucket/fake-cookies.txt")
      mocked_sentry.verify
    end

    PenderConfig.load('cookies')
    assert_equal PenderConfig.get('cookies'), {}
  end

  test 'keeps cookies as empty and reports problem if file downloaded from S3 is empty' do
    mocked_sentry = MiniTest::Mock.new
    mocked_sentry.expect :call, :return_value do |error, args|
      error.class.to_s.match(/S3DownloadError/) &&
        error.message.match(/Downloaded file from S3 is empty/) &&
        args[:provided_path] == 's3://fake-bucket/fake-cookies.txt'
    end

    # Below returns success, but does not write to the tmpfile
    Aws::S3::Client.any_instance.stubs(:get_object).returns(OpenStruct.new(successful?: true))

    PenderSentry.stub(:notify, mocked_sentry) do
      CookieLoader.load_from("s3://fake-bucket/fake-cookies.txt")
      mocked_sentry.verify
    end

    PenderConfig.load('cookies')
    assert_equal PenderConfig.get('cookies'), {}
  end
end
