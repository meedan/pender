require_relative '../test_helper'

class PenderConfigTest < ActiveSupport::TestCase

  test "should return nil for missing config" do
    assert_nil PenderConfig.get('missing')
  end

  test "should return value from api if present" do
    key1 = create_api_key application_settings: { config: { google_api_key: 'specific_key' }}
    key2 = create_api_key application_settings: {}
    key3 = create_api_key

    PenderConfig.current = nil
    ApiKey.current = key1
    assert_equal 'specific_key', PenderConfig.get('google_api_key')

    PenderConfig.current = nil
    ApiKey.current = key2
    assert_equal CONFIG['google_api_key'], PenderConfig.get('google_api_key')

    PenderConfig.current = nil
    ApiKey.current = key3
    assert_equal CONFIG['google_api_key'], PenderConfig.get('google_api_key')

    PenderConfig.current = nil
    ApiKey.current = nil
    assert_equal CONFIG['google_api_key'], PenderConfig.get('google_api_key')

    PenderConfig.current = nil
    ApiKey.current = nil
    assert_equal CONFIG['google_api_key'], PenderConfig.get('google_api_key')
  end

  test "should return default value if key is absent on config present" do
    key = create_api_key application_settings: { config: {}}

    PenderConfig.current = nil
    ApiKey.current = key
    assert_equal CONFIG['timeout'], PenderConfig.get('timeout')
    assert_nil PenderConfig.get('invalid-key', nil)
    assert_equal({}, PenderConfig.get('hash-key', {}))
  end

end
