require File.join(File.expand_path(File.dirname(__FILE__)), 'base_performance')

class FacebookPageProfileTest < BasePerformance
  def setup
    @provider = 'Facebook'
    @type = 'profile page'
    @url = 'https://www.facebook.com/ironmaiden'
  end
end
