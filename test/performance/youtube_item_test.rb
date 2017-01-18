require File.join(File.expand_path(File.dirname(__FILE__)), 'base_performance')

class YoutubeItemTest < BasePerformance
  def setup
    @provider = 'YouTube'
    @type = 'item'
    @url = 'https://www.youtube.com/watch?v=xx-pIwsZpPk'
  end
end
