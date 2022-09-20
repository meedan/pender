require 'test_helper'

class RequestHelperUnitTest < ActiveSupport::TestCase
  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  test "should return absolute url, preferring constructing from the path" do
    assert_equal 'https://www.example.com/', RequestHelper.absolute_url('https://www.example.com/')
    assert_equal 'https://www.test.bli', RequestHelper.absolute_url('https://www.example.com/', 'https://www.test.bli')
    assert_equal 'https://www.test.bli', RequestHelper.absolute_url('https://www.example.com/', '//www.test.bli')
    assert_equal 'https://www.example.com/example', RequestHelper.absolute_url('https://www.example.com/','/example')
    assert_equal 'http://www.test.bli', RequestHelper.absolute_url('https://www.example.com/', 'www.test.bli')
  end
end
