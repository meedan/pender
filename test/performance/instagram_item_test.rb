require File.join(File.expand_path(File.dirname(__FILE__)), 'base_performance')

class InstagramItemTest < BasePerformance
  def setup
    @provider = 'Instagram'
    @type = 'item'
    @url = 'https://www.instagram.com/p/BO2dRnHFy9q'
  end
end
