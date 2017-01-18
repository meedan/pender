require File.join(File.expand_path(File.dirname(__FILE__)), 'base_performance')

class FacebookUserItemTest < BasePerformance
  def setup
    @provider = 'Facebook'
    @type = 'user item'
    @url = 'https://www.facebook.com/photo.php?fbid=1151101418271444&set=a.195364547178474.48551.100001147915899&type=3'
  end
end
