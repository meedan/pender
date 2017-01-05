require File.join(File.expand_path(File.dirname(__FILE__)), 'base_performance')

class FacebookPageItemTest < BasePerformance
  def setup
    @provider = 'Facebook'
    @type = 'page item'
    @url = 'https://www.facebook.com/ironmaiden/photos/a.406269382050.189128.172685102050/10154050912862051/?type=3&theater'
  end
end
