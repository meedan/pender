module MediaTwitterProfile
  extend ActiveSupport::Concern

  included do
    Media.declare('twitter_profile', [/^https?:\/\/(www\.)?twitter\.com\/([^\/]+)$/])
  end

  def twitter_client
    Twitter::REST::Client.new do |config|
      config.consumer_key        = CONFIG['twitter_consumer_key']
      config.consumer_secret     = CONFIG['twitter_consumer_secret']
      config.access_token        = CONFIG['twitter_access_token'] 
      config.access_token_secret = CONFIG['twitter_access_token_secret']
    end
  end

  def data_from_twitter_profile
    username = self.data[:username] = self.get_twitter_username

    self.data.merge!(self.twitter_client.user(username).as_json)

    self.data.merge!({
      title: self.data['name'],
      picture: self.data['profile_image_url_https']
    })
  end

  def get_twitter_username
    self.url.match(/^https?:\/\/(www\.)?twitter\.com\/([^\/]+)$/)[2]
  end
end
