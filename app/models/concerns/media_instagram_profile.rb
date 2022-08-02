module MediaInstagramProfile
  extend ActiveSupport::Concern

  INSTAGRAM_PROFILE_URL = /^https?:\/\/(www\.)?instagram\.com\/([^\/]+)/

  included do
    Media.declare('instagram_profile', [INSTAGRAM_PROFILE_URL])
  end

  def data_from_instagram_profile
    username = self.url.match(INSTAGRAM_PROFILE_URL)[2]

    handle_exceptions(self, StandardError) do
      self.get_instagram_profile_data(username)
      data = self.data
      self.set_data_field('username', '@' + username)
      self.set_data_field('title', username)
      self.data.merge!({ external_id: username })

      return if data.dig('raw', 'api', 'error')
      self.set_data_field('description', data.dig('raw', 'api', 'user', 'biography'))
      self.set_data_field('picture', data.dig('raw', 'api', 'user', 'profile_pic_url'))
      self.set_data_field('author_name', data.dig('raw', 'api', 'user', 'full_name'))
      self.set_data_field('author_picture', data.dig('raw', 'api', 'user', 'profile_pic_url'))
      self.set_data_field('published_at', '')
    end
  end

  def get_instagram_profile_data(username)
    begin
      # We're using a private API for fetching data from Instagram
      self.data['raw']['api'] = self.get_instagram_profile_api_data("https://i.instagram.com/api/v1/users/web_profile_info/?username=#{username}")
    rescue StandardError => error
      Rails.logger.warn level: 'WARN', message: '[Parser] Cannot get data from Instagram URL', error_class: error.class, error_message: error.message
      self.data['raw']['api'] = { error: { message: error.message, code: LapisConstants::ErrorCodes::const_get('UNKNOWN') }}
    end
  end

  def get_instagram_profile_api_data(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    
    headers = Media.extended_headers(uri)
    headers.merge!({
      'x-ig-app-id': '936619743392459',
    })
    request = Net::HTTP::Get.new(uri.request_uri, headers)
    response = http.request(request)
    raise StandardError.new("#{response.class}: #{response.message}") unless %(200 301 302).include?(response.code)
    return JSON.parse(response.body)['data'] if response.code == '200'
    location = response.header['location']
    self.ignore_url?(location) ? (raise StandardError.new("Page unavailable, encountered #{self.unavailable_page}")) : self.get_instagram_profile_api_data(location)
  end
end 
