module MediaInstagramItem
  extend ActiveSupport::Concern

  INSTAGRAM_URL = /^https?:\/\/(www\.)?instagram\.com\/p\/([^\/]+)/

  included do
    Media.declare('instagram_item', [INSTAGRAM_URL])
  end

  def data_from_instagram_item
    id = self.url.match(INSTAGRAM_URL)[2]

    handle_exceptions(self, StandardError) do
      self.get_instagram_data(id.to_s)
      data = self.data
      self.data.merge!({
        username: '@' + data['raw']['api']['author_name'],
        description: data['raw']['api']['title'],
        title: data['raw']['api']['title'],
        picture: data['raw']['api']['thumbnail_url'],
        author_url: data['raw']['api']['author_url'],
        html: data['raw']['api']['html'],
        author_picture: data['raw']['graphql']['shortcode_media']['owner']['profile_pic_url'],
        author_name: data['raw']['graphql']['shortcode_media']['owner']['full_name'],
        published_at: self.get_instagram_datetime
      })
    end
  end

  def get_instagram_data(id)
    pool = []
    sources = { api: "https://api.instagram.com/oembed/?url=http://instagr.am/p/#{id}", graphql: "https://www.instagram.com/p/#{id}/?__a=1" }
    sources.each do |source|
      pool << Thread.new {
        data = self.get_instagram_json_data(source[1])
        self.data['raw'][source[0]] = (source[0] == :api) ? data : data['graphql']
      }
    end
    pool.each(&:join)
    self.data['raw']['oembed'] = self.data['raw']['api']
  end

  def get_instagram_datetime
    Time.parse(self.data['raw']['api']['html'].match(/.*datetime=\\?"([^"]+)\\?".*/)[1])
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
