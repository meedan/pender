module MediaInstagramItem
  extend ActiveSupport::Concern

  INSTAGRAM_URL = /^https?:\/\/(www\.)?instagram\.com\/p\/([^\/]+)/

  included do
    Media.declare('instagram_item', [INSTAGRAM_URL])
  end

  def data_from_instagram_item
    id = self.url.match(INSTAGRAM_URL)[2]

    handle_exceptions(RuntimeError) do
      data = self.get_instagram_oembed_data('https://api.instagram.com/oembed/?url=http://instagr.am/p/' + id.to_s)
      self.data.merge!(data)
      self.data.merge!({
        username: data['author_name'],
        description: data['title'],
        picture: data['thumbnail_url'],
        published_at: self.get_instagram_datetime
      })
    end
  end

  def get_instagram_datetime
    Time.parse(self.data['html'].match(/.*datetime=\\?"([^"]+)\\?".*/)[1])
  end

  def get_instagram_oembed_data(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true unless url.match(/^https/).nil?
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    raise "#{response.class}: #{response.message}" unless %(200 301 302).include?(response.code)
    response = self.get_instagram_oembed_data(response.header['location']) if %w(301 302).include?(response.code)
    JSON.parse(response.body)
  end
end 
