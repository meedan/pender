require 'pender/exception'

module ProviderTwitter
  extend ActiveSupport::Concern

  class ApiError < StandardError; end
  class ApiResponseCodeError < StandardError; end
  class ApiAuthenticationError < StandardError; end

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

  def user_lookup_by_id(id)
    params = {
      "ids": id,
      "user.fields": "profile_image_url,name,username,description,created_at,url",
    }

    get "users", params
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
      raise ApiResponseCodeError.new("#{response.class}: #{response.message}") unless (RequestHelper::REDIRECT_HTTP_CODES + ['200']).include?(response.code)
      JSON.parse(response.body) 
    rescue JSON::ParserError, ApiResponseCodeError, ApiAuthenticationError => e
      raise ApiError.new("#{e.class}: #{e.message}")
      PenderSentry.notify(e, url: url)
      @parsed_data[:raw][:api] = { error: { message: "#{error.class}: #{error.code} #{error.message}", code: Lapis::ErrorCodes::const_get('INVALID_VALUE') }}    
    end
  end

  def replace_subdomain_pattern(original_url)
    original_url.gsub(/:\/\/.*\.twitter\./, '://twitter.')
  end
end
