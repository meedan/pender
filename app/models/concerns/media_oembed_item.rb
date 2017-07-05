module MediaOembedItem
  extend ActiveSupport::Concern

  def get_oembed_url
    tag = self.doc.at_css('link[type="application/json+oembed"]')
    tag.nil? ? '' : tag.attribute('href').to_s
  end

  def post_process_oembed_data
    data = self.data
    self.data.merge!({
      published_at: '',
      username: data[:raw][:oembed]['author_name'],
      description: data[:raw][:oembed]['title'],
      title: data[:raw][:oembed]['title'],
      picture: data[:raw][:oembed]['thumbnail_url'].to_s,
      html: data[:raw][:oembed]['html'],
      author_url: data[:raw][:oembed]['author_url']
    })
  end

  def data_from_oembed_item
    handle_exceptions(self, StandardError) do
      oembed_url = self.get_oembed_url
      response = self.oembed_get_data_from_url(oembed_url)
      if !response.nil? && response.code == '200'
        self.data[:raw][:oembed] = JSON.parse(response.body)
        if ['DENY', 'SAMEORIGIN'].include? response.header['X-Frame-Options']
          self.data[:raw][:oembed][:html] = ''
        end
        self.post_process_oembed_data
      end
    end
  end

  def oembed_get_data_from_url(url)
    response = nil
    unless url.blank?
      uri = URI.parse(self.absolute_url(url))
      http = Net::HTTP.new(uri.host, uri.port)

      unless url.match(/^https/).nil?
        http.use_ssl = true
        # http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      request = self.oembed_create_request(uri)
      response = http.request(request)
      
      if %w(301 302).include?(response.code)
        response = self.oembed_get_data_from_url(response.header['location'])
      end
    end
    response
  end

  def oembed_create_request(uri)
    request = Net::HTTP::Get.new(uri.request_uri)
    credentials = self.get_http_auth(uri)
    request.basic_auth(credentials.first, credentials.last) unless credentials.blank?
    request
  end

  def oembed_as_oembed(_original_url, _maxwidth, _maxheight)
    data = self.as_json
    data[:oembed] || data['oembed']
  end
end
