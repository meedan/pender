require 'pender_exceptions'

module MediaTwitterProfile
  extend ActiveSupport::Concern

  URLS = [
    /^https?:\/\/(www\.)?twitter\.com\/([^\/]+)$/,
    /^https?:\/\/(0|m|mobile)\.twitter\.com\/([^\/]+)$/
  ]

  included do
    Media.declare('twitter_profile', URLS)
  end

  def twitter_client
    Twitter::REST::Client.new do |config|
      config.consumer_key        = PenderConfig.get('twitter_consumer_key')
      config.consumer_secret     = PenderConfig.get('twitter_consumer_secret')
      config.access_token        = PenderConfig.get('twitter_access_token')
      config.access_token_secret = PenderConfig.get('twitter_access_token_secret')
    end
  end

  def data_from_twitter_profile
    self.replace_subdomain_pattern
    username = self.get_twitter_username
    self.data[:raw][:api] = {}
    handle_twitter_exceptions do
      self.data[:raw][:api].merge!(self.twitter_client.user(username).as_json)
      self.process_twitter_profile_images
      self.set_data_field('picture', self.data[:pictures][:original])
      self.set_data_field('author_picture', self.data[:pictures][:original])
    end
    self.set_data_field('title', get_info_from_data('api', data, 'name'), username)
    self.data.merge!({
      external_id: username,
      username: '@' + username,
      author_name: self.data[:title],
      published_at: get_info_from_data('api', data, 'created_at'),
      description: get_info_from_data('api', data, 'description')
    })
  end
  
  def process_twitter_profile_images
    picture = self.data[:raw][:api][:profile_image_url_https].to_s
    self.data[:pictures] = {
      normal: picture,
      bigger: picture.gsub('_normal', '_bigger'),
      mini: picture.gsub('_normal', '_mini'),
      original: picture.gsub('_normal', '')
    }
  end

  def get_twitter_username
    self.url.match(/^https?:\/\/(www\.)?twitter\.com\/([^\/]+)$/)[2]
  end

  def replace_subdomain_pattern
    self.url.gsub!(/:\/\/.*\.twitter\./, '://twitter.')
  end
end
