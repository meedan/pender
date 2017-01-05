require File.join(File.expand_path(File.dirname(__FILE__)), 'base_performance')

class FacebookUserProfileTest < BasePerformance
  def setup
    @provider = 'Facebook'
    @type = 'user profile'
    @url = 'https://www.facebook.com/caiosba'
  end
end
