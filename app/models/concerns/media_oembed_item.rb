module MediaOembedItem
  extend ActiveSupport::Concern

  def get_oembed_url
    tag = self.doc.at_css('link[type="application/json+oembed"]')
    tag.nil? ? '' : tag.attribute('href').to_s
  end

  def post_process_oembed_data
    data = self.data
    return if data[:error] || data[:raw][:oembed].nil?
    data.merge({
      published_at: '',
      username: get_info_from_data('oembed', data, 'author_name'),
      description: get_info_from_data('oembed', data, 'summary', 'title'),
      title: get_info_from_data('oembed', data, 'title'),
      picture: get_info_from_data('oembed', data, 'thumbnail_url'),
      html: get_info_from_data('oembed', data, 'html'),
      author_url: get_info_from_data('oembed', data, 'author_url')
    })
  end

  def data_from_oembed_item
    return if data[:error]
    handle_exceptions(self, StandardError) do
      oembed_url = self.provider_oembed_url || self.get_oembed_url
      response = self.oembed_get_data_from_url(oembed_url)
      if !response.nil? && response.code == '200'
        self.data[:raw][:oembed] = JSON.parse(response.body)
        if ['DENY', 'SAMEORIGIN'].include? response.header['X-Frame-Options']
          self.data[:raw][:oembed][:html] = ''
        end
        return true
      end
    end
  end

  def oembed_get_data_from_url(url)
    response = nil
    unless url.blank?
      uri = URI.parse(self.absolute_url(url))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'

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

  def provider_oembed_url
    self.send("#{self.provider}_oembed_url") if self.respond_to?("#{self.provider}_oembed_url")
  end
end
