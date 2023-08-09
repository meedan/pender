require 'pender/exception'

module ProviderTwitter
  extend ActiveSupport::Concern

  class ApiError < StandardError; end

  BASE_URI = "https://api.twitter.com/2/"

  def oembed_url(_ = nil)
    "https://publish.twitter.com/oembed?url=#{self.url}"
  end

  def tweet_lookup(tweet_id)
    params = {
      "ids": tweet_id,
      "tweet.fields": "author_id,created_at,text",
      "expansions": "author_id,attachments.media_keys",
      "user.fields": "profile_image_url,username,url",
      "media.fields": "url",
    }

    get "tweets", params
  end

  def user_lookup_by_username(username)
    params = {
      "usernames": username,
      "user.fields": "profile_image_url,name,username,description,created_at,url",
    }

    get "users/by", params
  end

  private

  def get(path, params)
    uri = URI(URI.join(BASE_URI, path))
    uri.query = Rack::Utils.build_query(params)
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    headers = {
      "Authorization": "Bearer #{PenderConfig.get('twitter_bearer_token')}",
    }
    
    request = Net::HTTP::Get.new(uri.request_uri, headers)

    begin
      response = http.request(request)
      raise ApiError.new("#{response.class}: #{response.code} #{response.message} - #{response.body}") unless response.code.to_i < 400
      JSON.parse(response.body) 
    rescue StandardError => e
      PenderSentry.notify(e, url: url)
      raise ApiError.new("#{e.class}: #{e.message}")
    end
  end

  def replace_subdomain_pattern(original_url)
    original_url.gsub(/:\/\/.*\.twitter\./, '://twitter.')
  end
end
