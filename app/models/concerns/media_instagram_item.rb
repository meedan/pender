module MediaInstagramItem
  extend ActiveSupport::Concern

  INSTAGRAM_URL = /^https?:\/\/(www\.)?instagram\.com\/p\/([^\/]+)/

  included do
    Media.declare('instagram_item', [INSTAGRAM_URL])
  end

  def data_from_instagram_item
    id = self.url.match(INSTAGRAM_URL)[2]

    handle_exceptions(RuntimeError) do
      self.get_instagram_data(id.to_s)
      data = self.data
      self.data.merge!({
        username: data['author_name'],
        description: data['title'],
        picture: data['thumbnail_url'],
        author_picture: data['media']['owner']['profile_pic_url'],
        published_at: self.get_instagram_datetime
      })
    end
  end

  def get_instagram_data(id)
    pool = []
    links = ["https://api.instagram.com/oembed/?url=http://instagr.am/p/#{id}", "https://www.instagram.com/p/#{id}/?__a=1"]
    links.each do |link|
      pool << Thread.new {
        self.data.merge! self.get_instagram_json_data(link)
      }
    end
    pool.each(&:join)
  end

  def get_instagram_datetime
    Time.parse(self.data['html'].match(/.*datetime=\\?"([^"]+)\\?".*/)[1])
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
