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
      "media.fields": "url"
    }

    get "tweets?#{Rack::Utils.build_nested_query(params)}"
  end

  def user_lookup_by_username(username)
  end
  
  private

  def self.get(path)
    uri = URI(URI.join(BASE_URI, path))
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    headers = {
      "Authorization": "Bearer #{PenderConfig.get('twitter_bearer_token')}",
      "Content-Type": "application/json"
    }
    
    request = Net::HTTP::Get.new(uri.request_uri, headers)

    response = http.request(request)
    JSON.parse(response.body) 
    end
end