require 'pender/exception'

module ProviderTwitter
  extend ActiveSupport::Concern

  def oembed_url(_ = nil)
    "https://publish.twitter.com/oembed?url=#{self.url}"
  end

  private

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
