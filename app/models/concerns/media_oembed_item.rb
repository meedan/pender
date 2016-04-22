module MediaOembedItem
  extend ActiveSupport::Concern

  included do
    Media.declare('oembed_item', [/^.*$/])
  end

  def get_oembed_url
    require 'open-uri'
    doc = Nokogiri::HTML(open(self.url, allow_redirections: :safe))
    tag = doc.at_css('link[type="application/json+oembed"]')
    tag.nil? ? '' : tag.attribute('href').to_s
  end

  def post_process_oembed_data
    data = self.data
    self.data.merge!({
      published_at: '',
      username: data[:oembed]['author_name'],
      description: data[:oembed]['title'],
      title: data[:oembed]['title'],
      picture: ''
    })
  end

  def data_from_oembed_item
    oembed_url = self.get_oembed_url
    if oembed_url
      uri = URI.parse(oembed_url)
      http = Net::HTTP.new(uri.host, uri.port)

      unless oembed_url.match(/^https/).nil?
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      
      if response.code == '301'
        response = Net::HTTP.get_response(URI.parse(response.header['location']))
      end
      
      if response.code == '200'
        self.data[:oembed] = JSON.parse(response.body)
        self.post_process_oembed_data
      end
    end
  end

  def oembed_as_oembed(_original_url, _maxwidth, _maxheight)
    self.data[:oembed] || self.data['oembed']
  end
end
