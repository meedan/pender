module MediaInstagramItem
  extend ActiveSupport::Concern

  INSTAGRAM_URL = /^https?:\/\/(www\.)?instagram\.com\/(p|tv)\/([^\/]+)/

  included do
    Media.declare('instagram_item', [INSTAGRAM_URL])
  end

  def data_from_instagram_item
    id = self.url.match(INSTAGRAM_URL)[3]

    handle_exceptions(self, StandardError) do
      self.get_instagram_data(id.to_s)
      self.data.merge!(external_id: id)
      data = self.data
      return if data.dig('raw', 'graphql', 'error') && data.dig('raw', 'crowdtangle', 'error')
      self.set_data_field('username', self.get_instagram_username_from_data)
      self.set_data_field('description', self.get_instagram_text_from_data)
      self.set_data_field('title', self.get_instagram_text_from_data)
      self.set_data_field('picture', self.get_instagram_picture_from_data)
      self.set_data_field('author_name', data.dig('raw', 'graphql', 'user', 'full_name'))
      self.set_data_field('author_picture', data.dig('raw', 'graphql', 'user', 'profile_pic_url'))
      self.data.merge!({ external_id: id })
    end
  end

  def get_instagram_username_from_data
    username = get_info_from_data('crowdtangle', self.data, 'handle')
    username = username.blank? ? data.dig('raw', 'graphql', 'user', 'username').to_s : username
    username.prepend('@') unless username.blank?
  end

  def get_instagram_text_from_data
    self.data.dig('raw', 'graphql', 'caption', 'text').to_s
  end

  def get_instagram_picture_from_data
    picture = get_info_from_data('api', self.data, 'thumbnail_url')
    picture.blank? ? self.data.dig('raw', 'graphql', 'user', 'profile_pic_url') : picture
  end

  def get_instagram_data(id)
    begin
      self.data['raw']['graphql'] = self.get_instagram_graphql_data("https://www.instagram.com/p/#{id}/?__a=1")
    rescue StandardError => error
      Rails.logger.warn level: 'WARN', message: '[Parser] Cannot get data from Instagram URL', error_class: error.class, error_message: error.message
      self.data['raw']['graphql'] = { error: { message: error.message, code: LapisConstants::ErrorCodes::const_get('UNKNOWN') }}
    end
    self.get_crowdtangle_data(:instagram)
  end

  def get_instagram_graphql_data(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    headers = Media.extended_headers(uri)
    request = Net::HTTP::Get.new(uri.request_uri, headers)
    response = http.request(request)
    raise StandardError.new("#{response.class}: #{response.message}") unless %(200 301 302).include?(response.code)
    return JSON.parse(response.body)['items'][0] if response.code == '200'
    location = response.header['location']
    self.ignore_url?(location) ? (raise StandardError.new('Login required')) : self.get_instagram_graphql_data(location)
  end
end 
