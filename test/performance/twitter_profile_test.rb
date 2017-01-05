require File.join(File.expand_path(File.dirname(__FILE__)), 'base_performance')

class TwitterProfileTest < BasePerformance
  def setup
    @provider = 'Twitter'
    @type = 'profile'
    @url = 'https://twitter.com/meedan'
  end
end
