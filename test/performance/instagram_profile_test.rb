require File.join(File.expand_path(File.dirname(__FILE__)), 'base_performance')

class InstagramProfileTest < BasePerformance
  def setup
    @provider = 'Instagram'
    @type = 'profile'
    @url = 'https://www.instagram.com/ironmaiden/'
  end
end
