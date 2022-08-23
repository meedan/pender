module MediaInstagramProfile
  extend ActiveSupport::Concern

  INSTAGRAM_PROFILE_URL = /^https?:\/\/(www\.)?instagram\.com\/([^\/]+)/

  included do
    Media.declare('instagram_profile', [INSTAGRAM_PROFILE_URL])
  end

  def data_from_instagram_profile
    username = self.url.match(INSTAGRAM_PROFILE_URL)[2]

    handle_exceptions(self, StandardError) do
      self.set_data_field('username', '@' + username)
      self.set_data_field('title', username)
      self.set_data_field('description', self.url)
      self.data.merge!({ external_id: username })

      response_data = self.get_instagram_api_data(
        "https://i.instagram.com/api/v1/users/web_profile_info/?username=#{username}",
        additional_headers: { 'x-ig-app-id': '936619743392459' }
      )
      return if self.data['error']
      self.data['raw']['api'] = response_data['data']
      # If we use set_data_field, it won't override the default value above
      self.data['description'] = self.data.dig('raw', 'api', 'user', 'biography')
      self.set_data_field('picture', self.data.dig('raw', 'api', 'user', 'profile_pic_url'))
      self.set_data_field('author_name', self.data.dig('raw', 'api', 'user', 'full_name'))
      self.set_data_field('author_picture', self.data.dig('raw', 'api', 'user', 'profile_pic_url'))
      self.set_data_field('published_at', '')
    end
  end

  def get_instagram_api_data(url, additional_headers: {})
    begin
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      
      headers = Media.extended_headers(uri)
      headers.merge!(additional_headers)

      request = Net::HTTP::Get.new(uri.request_uri, headers)
      response = http.request(request)
      raise StandardError.new("#{response.class}: #{response.message}") unless %(200 301 302).include?(response.code)
      return JSON.parse(response.body) if response.code == '200'

      location = response.header['location']
      if self.ignore_url?(location)
        raise Instagram::ApiAuthenticationError.new("Page unreachable, received redirect for #{self.unavailable_page} to #{location}")
      else
        self.get_instagram_api_data(location)
      end
    # Deliberately catch and re-wrap any errors we think are related
    # to the API not working as expected, so that we can monitor them
    rescue JSON::ParserError, Instagram::ApiAuthenticationError => e
      raise Instagram::ApiError.new("#{e.class}: #{e.message}")
    # Catch all for other errors - this was the behavior before the creation
    # of the classes above. Assume it is to catch 404s, mostly
    rescue StandardError => error
      Rails.logger.warn level: 'WARN', message: '[Parser] Cannot get data from Instagram URL', error_class: error.class, error_message: error.message
      self.data['error'] = { message: error.message, code: LapisConstants::ErrorCodes::const_get('UNKNOWN') }
    end
  end
  
  def ignore_instagram_urls
    [
      { pattern: /^https:\/\/www\.instagram\.com\/accounts\/login/, reason: :login_page },
      { pattern: /^https:\/\/www\.instagram\.com\/challenge\?/, reason: :account_challenge_page },
      { pattern: /^https:\/\/www\.instagram\.com\/privacy\/checks/, reason: :privacy_check_page },
    ]
  end
end 
