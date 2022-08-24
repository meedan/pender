require 'pender_exceptions'

module ProviderTwitter
  extend ActiveSupport::Concern

  # class ApiError < StandardError; end
  # class ApiResponseCodeError < StandardError; end
  # class ApiAuthenticationError < StandardError; end

  # class_methods do
  #   def ignored_urls
  #     []
  #   end
  # end

  def initialize(url)
    super(url)

    @twitter_client = Twitter::REST::Client.new do |config|
      config.consumer_key        = PenderConfig.get('twitter_consumer_key')
      config.consumer_secret     = PenderConfig.get('twitter_consumer_secret')
      config.access_token        = PenderConfig.get('twitter_access_token')
      config.access_token_secret = PenderConfig.get('twitter_access_token_secret')
    end
  end

  # def oembed_url
  #   "https://publish.twitter.com/oembed?url=#{url}"
  # end

  attr_reader :twitter_client

  private

  def handle_twitter_exceptions
    begin
      yield
    rescue Twitter::Error::TooManyRequests => e
      raise Pender::ApiLimitReached.new(e.rate_limit.reset_in)
    rescue Twitter::Error => error
      PenderAirbrake.notify(error, url: url )
      @parsed_data[:raw][:api] = { error: { message: "#{error.class}: #{error.code} #{error.message}", code: LapisConstants::ErrorCodes::const_get('INVALID_VALUE') }}
      Rails.logger.warn level: 'WARN', message: "[Parser] #{error.message}", url: url, code: error.code, error_class: error.class
      return
    end
  end

  def replace_subdomain_pattern(original_url)
    original_url.gsub(/:\/\/.*\.twitter\./, '://twitter.')
  end
end
