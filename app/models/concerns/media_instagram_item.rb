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
      raise data.dig('raw', 'api', 'error', 'message') if data.dig('raw', 'api', 'error') && data.dig('raw', 'graphql', 'error')
      self.data.merge!({
        external_id: id,
        username: '@' + get_instagram_username_from_data,
        description: get_instagram_text_from_data,
        title: get_instagram_text_from_data,
        picture: get_instagram_picture_from_data,
        author_url: get_info_from_data('api', data, 'author_url'),
        html: get_info_from_data('api', data, 'html'),
        author_picture: data.dig('raw', 'graphql', 'shortcode_media', 'owner', 'profile_pic_url'),
        author_name: data.dig('raw', 'graphql', 'shortcode_media', 'owner', 'full_name'),
        published_at: self.get_instagram_datetime
      })
    end
  end

  def get_instagram_username_from_data
    username = get_info_from_data('api', self.data, 'author_name')
    username.blank? ? (data.dig('raw', 'graphql', 'shortcode_media', 'owner', 'username') || '' ) : username
  end

  def get_instagram_text_from_data
    text = get_info_from_data('api', self.data, 'title')
    return text unless text.blank?
    text = self.data.dig('raw', 'graphql', 'shortcode_media', 'edge_media_to_caption', 'edges')
    (!text.blank? && text.is_a?(Array)) ? text.first.dig('node', 'text') : ''
  end

  def get_instagram_picture_from_data
    picture = get_info_from_data('api', self.data, 'thumbnail_url')
    picture.blank? ? self.data.dig('raw', 'graphql', 'shortcode_media', 'display_url') : picture
  end

  def get_instagram_data(id)
    pool = []
    sources = { api: "https://api.instagram.com/oembed/?url=http://instagr.am/p/#{id}", graphql: "https://www.instagram.com/p/#{id}/?__a=1" }
    sources.each do |source|
      pool << Thread.new {
        begin
          data = self.get_instagram_json_data(source[1])
          self.data['raw'][source[0]] = (source[0] == :api) ? data : data['graphql']
        rescue StandardError => error
          Airbrake.notify(error.message, instagram_source: source) if Airbrake.configured?
          Rails.logger.info "[Instagram URL] Cannot get data from '#{source[0]}' (#{source[1]}): (#{error.class}) #{error.message}"
          self.data['raw'][source[0]] = { error: { message: error.message }}
        end
      }
    end
    pool.each(&:join)
    self.data['raw']['oembed'] = self.data['raw']['api']
  end

  def get_instagram_datetime
    datetime = get_info_from_data('api', self.data, 'html').match(/.*datetime=\\?"([^"]+)\\?".*/)
    datetime ? Time.parse(datetime[1]) : ''
  end

  def get_instagram_json_data(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true unless url.match(/^https/).nil?
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    raise "#{response.class}: #{response.message}" unless %(200 301 302).include?(response.code)
    response = self.get_instagram_json_data(response.header['location']) if %w(301 302).include?(response.code)
    JSON.parse(response.body)
  end
end 
