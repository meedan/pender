require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class SaveScreenshotWorkerTest < ActiveSupport::TestCase
  test "should take screenshot" do
    Media.any_instance.unstub(:generate_screenshot)
    CcDeville.stubs(:clear_cache_for_url)
    a = create_api_key application_settings: { 'webhook_url': 'https://webhook.site/19cfeb40-3d06-41b8-8378-152fe12e29a8', 'webhook_token': 'test' }
    url = 'https://twitter.com/marcouza'
    id = Media.get_id(url)
    m = create_media url: url, key: a
    data = m.as_json
    filename = url.parameterize + '.png'
    path = File.join(Rails.root, 'public', 'screenshots', filename)
    assert File.exists?(path)
    assert_equal 0, Rails.cache.read(id)['screenshot_taken']
    assert_nil Rails.cache.read(id)['webhook_called']
    
    w = SaveScreenshotWorker.new
    w.perform
    
    dimensions = IO.read(path)[0x10..0x18].unpack('NN')
    assert dimensions[1] > 2000
    assert_equal 1, Rails.cache.read(id)['screenshot_taken']
    assert_equal 1, Rails.cache.read(id)['webhook_called']
    CcDeville.unstub(:clear_cache_for_url)
  end
end
