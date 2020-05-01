module MediaTiktokItem
  extend ActiveSupport::Concern

  TIKTOK_URL = /^https?:\/\/(www\.)?tiktok\.com\/(?<username>[^\/]+)\/video\/(?<id>[^\/|?]+)/

  included do
    Media.declare('tiktok_item', [TIKTOK_URL])
  end

  def data_from_tiktok_item
    handle_exceptions(self, StandardError) do
      self.get_tiktok_api_data
      match = self.url.match(TIKTOK_URL)
      self.data.merge!({
        username: match['username'],
        external_id: match['id'],
        description: data['raw']['api']['title'],
        title: data['raw']['api']['title'],
        picture: data['raw']['api']['thumbnail_url'],
        author_url: data['raw']['api']['author_url'],
        html: data['raw']['api']['html'],
        author_picture: self.get_tiktok_author_picture,
        author_name: data['raw']['api']['author_name']
      })
    end
  end

  def get_tiktok_api_data
    uri = URI.parse(self.tiktok_oembed_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    raise "#{response.class}: #{response.message}" unless %(200 301 302).include?(response.code)
    self.data['raw']['oembed'] = self.data['raw']['api'] = JSON.parse(response.body)
  end

  def get_tiktok_author_picture
    avatar = self.doc.at_css('.user-info .avatar avatar-wrapper')
    avatar['style'].match(/url\("(.+)"\)/)[1] if avatar && avatar['style']
  end

  def tiktok_oembed_url
    "https://www.tiktok.com/oembed?url=#{self.url}"
  end

end
