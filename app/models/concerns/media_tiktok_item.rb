module MediaTiktokItem
  extend ActiveSupport::Concern

  TIKTOK_ITEM_URL = /^https?:\/\/(www\.)?tiktok\.com\/(?<username>[^\/]+)\/video\/(?<id>[^\/|?]+)/

  included do
    Media.declare('tiktok_item', [TIKTOK_ITEM_URL])
  end

  def data_from_tiktok_item
    handle_exceptions(self, StandardError) do
      self.set_data_field('description', self.url)

      self.get_tiktok_api_data
      match = self.url.match(TIKTOK_ITEM_URL)
      self.data.merge!({
        username: match['username'],
        external_id: match['id'],
        description: data['raw']['api']['title'],
        title: data['raw']['api']['title'],
        picture: data['raw']['api']['thumbnail_url'],
        author_url: data['raw']['api']['author_url'],
        html: data['raw']['api']['html'],
        author_name: data['raw']['api']['author_name']
      })
    end
  end

  def get_tiktok_api_data
    uri = URI.parse(self.tiktok_oembed_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    headers = Media.extended_headers(uri)
    request = Net::HTTP::Get.new(uri.request_uri, headers)
    response = http.request(request)
    self.data['raw'] ||= {}
    self.data['raw']['oembed'] = self.data['raw']['api'] = JSON.parse(response.body)
  end

  def tiktok_oembed_url
    "https://www.tiktok.com/oembed?url=#{self.url}"
  end
end
