require File.join(File.expand_path(File.dirname(__FILE__)), 'base_performance')

class YoutubeProfileTest < BasePerformance
  def setup
    @provider = 'YouTube'
    @type = 'profile'
    @url = 'https://www.youtube.com/user/ironmaiden'
  end
end
