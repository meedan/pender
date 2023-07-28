require 'json'
require 'net/http'

class TwitterClient
  # tweet_id = "1684310862842982400"
  BASE_URI = "https://api.twitter.com/2/"

  def self.tweet_lookup(tweet_id)
    params = {
      "ids": tweet_id,
      "tweet.fields": "author_id,created_at,text",
      "expansions": "author_id,attachments.media_keys",
      "user.fields": "profile_image_url,username,url",
      "media.fields": "url",
    }

    get "tweets", params
  end

  def self.user_lookup_by_username(username)
    params = {
      "usernames": username,
      "user.fields": "profile_image_url,name,username,description,created_at,url",
    }

    get "users/by", params
  end

  def self.user_lookup_by_id(id)
    params = {
      "ids": id,
      "user.fields": "profile_image_url,name,username,description,created_at,url",
    }

    get "users", params
  end

  private

  def self.get(path, params)
    uri = URI(URI.join(BASE_URI, path))
    uri.query = Rack::Utils.build_query(params)
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    headers = {
      "Authorization": "Bearer #{PenderConfig.get('twitter_bearer_token')}",
    }
    
    request = Net::HTTP::Get.new(uri.request_uri, headers)

    response = http.request(request)
    JSON.parse(response.body) 
    end
end