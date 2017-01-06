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
    tmp = File.join(Rails.root, 'tmp')
    if File.exists?(tmp)
      Rails.cache.clear
    else
      FileUtils.mkdir(tmp)
    end
  end

  def test_1_validate_link
    with_time('Validation') { Media.validate_url(@url) unless @url.blank? }
    puts
  end

  def test_2_instantiate_link
    with_time('Instantiation') { @@media = Media.new(url: @url) unless @url.blank? }
    puts
  end

  def test_3_parse_link
    with_time('Parsing') { @@media.send(:parse) unless @url.blank? }
    puts "        title: #{@@media.data['title']}"
  end
end
