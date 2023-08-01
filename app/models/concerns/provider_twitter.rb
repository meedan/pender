require 'pender/exception'

module ProviderTwitter
  extend ActiveSupport::Concern

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
      JSON.parse(response.body) 
    rescue Net::HTTPExceptions => e
      raise Pender::Exception::RetryLater, "(#{response.code}) #{response.message}"
    rescue JSON::ParserError => e
      Rails.logger.warn level: 'WARN', message: '[Parser] Could not get `twitter` data', twitter_url: uri, error_class: error.class, response_code: response.code, response_body: response.body
    end
  end

  def handle_twitter_exceptions
    begin
      yield
    rescue Twitter::Error::TooManyRequests => e
      raise Pender::Exception::ApiLimitReached.new(e.rate_limit.reset_in)
    rescue Twitter::Error => error
      PenderSentry.notify(error, url: url)
      @parsed_data[:raw][:api] = { error: { message: "#{error.class}: #{error.code} #{error.message}", code: Lapis::ErrorCodes::const_get('INVALID_VALUE') }}
      Rails.logger.warn level: 'WARN', message: "[Parser] #{error.message}", url: url, code: error.code, error_class: error.class
      return
    end
  end

  def replace_subdomain_pattern(original_url)
    original_url.gsub(/:\/\/.*\.twitter\./, '://twitter.')
  end
end
