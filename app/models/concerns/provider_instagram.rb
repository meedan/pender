module ProviderInstagram
  extend ActiveSupport::Concern

  class ApiError < StandardError; end
  class ApiResponseCodeError < StandardError; end
  class ApiAuthenticationError < StandardError; end

  class_methods do
    def ignored_urls
      [
        {
          pattern: /^https:\/\/www\.instagram\.com\/accounts\/login/,
          reason: :login_page
        },
        {
          pattern: /^https:\/\/www\.instagram\.com\/login\//,
          reason: :login_page
        },
        {
          pattern: /^https:\/\/www\.instagram\.com\/challenge\//,
          reason: :account_challenge_page
        },
        {
          pattern: /^https:\/\/www\.instagram\.com\/privacy\/checks/,
          reason: :privacy_check_page
        },
      ]
    end
  end

  def get_instagram_api_data(api_url, additional_headers: {})
    begin
      uri = RequestHelper.parse_url(api_url)
      http = Net::HTTP.new(uri.host, uri.inferred_port)
      http.use_ssl = uri.scheme == 'https'

      headers = RequestHelper.extended_headers(uri)
      headers.merge!(additional_headers)

      request = Net::HTTP::Get.new(uri.request_uri, headers)
      response = http.request(request)
      raise ApiResponseCodeError.new("#{response.class}: #{response.message}") unless (RequestHelper::REDIRECT_HTTP_CODES + ['200']).include?(response.code)
      return JSON.parse(response.body) if response.code == '200'

      location = response.header['location']
      if unavailable_reason = ignore_url?(location)
        raise ApiAuthenticationError.new("Page unreachable, received redirect for #{unavailable_reason}")
      else
        get_instagram_api_data(location)
      end
    # Deliberately catch and re-wrap any errors we think are related
    # to the API not working as expected, so that we can monitor them
    rescue JSON::ParserError, ApiResponseCodeError, ApiAuthenticationError => e
      raise ApiError.new("#{e.class}: #{e.message}")
    end
  end
end
