require_relative '../test_helper'

class PenderConfigTest < ActiveSupport::TestCase

  test "should return nil for missing config" do
    assert_nil PenderConfig.get('missing')
  end

  test "should return value from api if present" do
    ENV['key_for_test'] = 'env_key'

    key1 = create_api_key application_settings: { config: { key_for_test: 'api_specific_key' }}
    key2 = create_api_key application_settings: {}
    key3 = create_api_key

    PenderConfig.current = nil
    ApiKey.current = key1
    assert_equal 'api_specific_key', PenderConfig.get('key_for_test')

    PenderConfig.current = nil
    ApiKey.current = key2
    assert_equal 'env_key', PenderConfig.get('key_for_test')

    PenderConfig.current = nil
    ApiKey.current = key3
    assert_equal 'env_key', PenderConfig.get('key_for_test')

    PenderConfig.current = nil
    ApiKey.current = nil
    assert_equal 'env_key', PenderConfig.get('key_for_test')

    ENV.delete('key_for_test')
  end

  test "should return default value if key is absent on api key config" do
    key = create_api_key application_settings: { config: {}}

    PenderConfig.current = nil
    ApiKey.current = key
    assert_equal 10, PenderConfig.get('numeric-key', 10)
    assert_nil PenderConfig.get('invalid-key', nil)
    assert_equal({}, PenderConfig.get('hash-key', {}))
  end

  test "should return value from ENV if present and not on api" do
    env_values = {}
    ['google_api_key', 'twitter_consumer_secret', 'facebook_app_secret'].each do |key|
      env_values[key] = ENV[key]
      ENV[key] = "env_#{key}"
    end

    PenderConfig.current = nil
    ApiKey.current = create_api_key application_settings: { config: { google_api_key: 'api_google_api_key' }}
    assert_equal 'api_google_api_key', PenderConfig.get('google_api_key')
    assert_equal 'env_google_api_key', ENV['google_api_key']
    assert_equal 'env_twitter_consumer_secret', PenderConfig.get('twitter_consumer_secret')
    assert_equal 'env_facebook_app_secret', PenderConfig.get('facebook_app_secret')

    ['google_api_key', 'twitter_consumer_secret', 'facebook_app_secret'].each do |key|
      ENV[key] = env_values[key]
    end
  end

  test "should return default value if raises error when parsing json" do
    PenderConfig.current = nil
    config = { :hosts => "{ domain:{ country: us }}" }
    ApiKey.current = create_api_key application_settings: { config: config }
    assert_equal({}, PenderConfig.get('hosts', {}, :json))
  end

end
