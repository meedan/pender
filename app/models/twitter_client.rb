require 'json'
require 'net/http'

class TwitterClient
  # tweet_ids = "1684310862842982400"
  BASE_URI = "https://api.twitter.com/2/"

  def self.tweet_lookup(tweet_id)
    get "tweets?ids=#{tweet_id}&tweet.fields=author_id,created_at,text&expansions=author_id,attachments.media_keys&user.fields=profile_image_url,username,url&media.fields=url"
  end

  def user_lookup_by_username(username)
  end
  
  private

  def self.get(path)
    uri = URI(URI.join(BASE_URI, path))
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    headers = {
      # "User-Agent": "v2TweetLookupRuby",
      "Authorization": "Bearer #{PenderConfig.get('twitter_bearer_token')}",
      "Content-Type": "application/json"
    }
    
    request = Net::HTTP::Get.new(uri.request_uri, headers)

    response = http.request(request)
    JSON.parse(response.body) 
    end
end



# headers = { 'User-Agent' => 'Mozilla/5.0 (compatible; Pender/0.1; +https://github.com/meedan/pender)' }.merge(RequestHelper.get_cf_credentials(uri))
# request = Net::HTTP::Get.new(uri.request_uri, headers)
# response = http.request(request)

# from twitter github
# params = {
# 	"ids": tweet_ids,
#   # "expansions": "author_id,referenced_tweets.id",
#   "tweet.fields": "attachments,author_id,conversation_id,created_at,entities,geo,id,in_reply_to_user_id,lang",
#   # "user.fields": "name"
#   # "media.fields": "url", 
#   # "place.fields": "country_code",
#   # "poll.fields": "options"
# }

# def tweet_lookup(url, bearer_token, params)
#   options = {
#     method: 'get',
#     headers: {
#       "User-Agent": "v2TweetLookupRuby",
#       "Authorization": "Bearer #{bearer_token}"
#     },
#     params: params
#   }

#   request = Typhoeus::Request.new(url, options)
#   response = request.run

#   return response