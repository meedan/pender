require_relative '../test_helper'

class BasePerformance < ActiveSupport::TestCase

  def self.test_order
    :alpha
  end

  def teardown
    tmp = File.join(Rails.root, 'tmp', 'cache')
    if File.exists?(tmp)
      Rails.cache.clear
    else
      FileUtils.mkdir_p(tmp)
    end
  end

  test "1 validate_link" do
    with_time('validate') { Media.validate_url(@url) unless @url.blank? }
  end

  test "2 instantiate_link" do
    with_time('instantiate') { @@media = Media.new(url: @url) unless @url.blank? }
  end

  test "3 parse_link" do
    with_time('parse') { @@media.send(:parse) unless @url.blank? }
  end
end
