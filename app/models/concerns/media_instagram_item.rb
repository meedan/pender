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
      self.data.merge!({
        external_id: id,
        username: '@' + get_instagram_username_from_data,
        description: get_instagram_text_from_data,
        title: get_instagram_text_from_data,
        picture: get_instagram_picture_from_data,
        html: '',
        author_picture: data.dig('raw', 'graphql', 'shortcode_media', 'owner', 'profile_pic_url'),
        author_name: data.dig('raw', 'graphql', 'shortcode_media', 'owner', 'full_name')
      })
    end
  end

  def get_instagram_username_from_data
    username = get_info_from_data('crowdtangle', self.data, 'handle')
    username.blank? ? (data.dig('raw', 'graphql', 'shortcode_media', 'owner', 'username') || '' ) : username
  end

  def get_instagram_text_from_data
    return self.data['description'] unless self.data['description'].blank?
    text = self.data.dig('raw', 'graphql', 'shortcode_media', 'edge_media_to_caption', 'edges')
    (!text.blank? && text.is_a?(Array)) ? text.first.dig('node', 'text') : ''
  end

  def get_instagram_picture_from_data
    picture = get_info_from_data('api', self.data, 'thumbnail_url')
    picture.blank? ? self.data.dig('raw', 'graphql', 'shortcode_media', 'display_url') : picture
  end

  def get_instagram_data(id)
    begin
      self.data['raw']['graphql'] = self.get_instagram_graphql_data("https://www.instagram.com/p/#{id}/?__a=1")
    rescue StandardError => error
      Rails.logger.warn level: 'WARN', message: '[Parser] Cannot get data from Instagram URL', error_class: error.class, error_message: error.message
      self.data['raw']['graphql'] = { error: { message: error.message, code: LapisConstants::ErrorCodes::const_get('UNKNOWN') }}
    end
    self.get_crowdtangle_instagram_data
  end

  def get_instagram_graphql_data(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    headers = { 'User-Agent' => Media.html_options(uri)['User-Agent'] }
    request = Net::HTTP::Get.new(uri.request_uri, headers)
    response = http.request(request)
    raise StandardError.new("#{response.class}: #{response.message}") unless %(200 301 302).include?(response.code)
    return JSON.parse(response.body)['graphql'] if response.code == '200'
    location = response.header['location']
    raise StandardError.new('Login required') if Media.is_a_login_page(location)
    self.get_instagram_graphql_data(location)
  end

  def get_crowdtangle_instagram_data
    media_info = self.data.dig('raw', 'graphql', 'shortcode_media')
    self.data['raw']['crowdtangle'] = { error: { message: 'Cannot get data from Crowdtangle. Unknown ID', code: LapisConstants::ErrorCodes::const_get('UNKNOWN') }} and return if media_info.nil?
    id ="#{media_info['id']}_#{media_info['owner']['id']}"
    crowdtangle_data = Media.crowdtangle_request('instagram', id)
    return unless crowdtangle_data && crowdtangle_data['result']
    self.data['raw']['crowdtangle'] = crowdtangle_data['result']
    post_info = crowdtangle_data['result']['posts'].first
    self.data[:author_name] = post_info['account']['name']
    self.data[:username] = post_info['account']['handle']
    self.data[:author_picture] = post_info['account']['profileImage']
    self.data[:author_url] = post_info['account']['url']
    self.data[:description] = self.data[:title]  = post_info['description']
    self.data[:picture] = post_info['media'].first['url'] if post_info['media']
    self.data[:published_at] = post_info['date']
  end

end 
