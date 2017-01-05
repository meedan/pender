require File.join(File.expand_path(File.dirname(__FILE__)), 'base_performance')

class TwitterItemTest < BasePerformance
  def setup
    @provider = 'Twitter'
    @type = 'item'
    @url = 'https://twitter.com/meedan/status/773947372527288320'
  end
end
