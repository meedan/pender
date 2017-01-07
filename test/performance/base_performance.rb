require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'rails/performance_test_help'

class BasePerformance < ActionDispatch::PerformanceTest
  self.profile_options = { runs: 0, metrics: [:process_time] }

  def self.test_order
    :alpha
  end

  def setup
    @provider = nil
    @type = nil
  end

  def teardown
    tmp = File.join(Rails.root, 'tmp', 'cache')
    if File.exists?(tmp)
      Rails.cache.clear
    else
      FileUtils.mkdir_p(tmp)
    end
  end

  def test_1_validate_link
    with_time('validate') { Media.validate_url(@url) unless @url.blank? }
  end

  def test_2_instantiate_link
    with_time('instantiate') { @@media = Media.new(url: @url) unless @url.blank? }
  end

  def test_3_parse_link
    with_time('parse') { @@media.send(:parse) unless @url.blank? }
  end
end
