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
      if !response.nil? && response.code == '200' && !response.body.blank?
        self.data[:raw][:oembed] = JSON.parse(response.body)
        self.verify_oembed_html
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
    request.add_field('User-Agent', 'Mozilla/5.0 (compatible; Pender/0.1; +https://github.com/meedan/pender)')
    credentials = Media.get_http_auth(uri)
    request.basic_auth(credentials.first, credentials.last) unless credentials.blank?
    request
  end

  def provider_oembed_url
    self.send("#{self.provider}_oembed_url") if self.respond_to?("#{self.provider}_oembed_url")
  end

  #
  # Discard the oEmbed's HTML fragment in the following cases:
  # - The script.src URL is not HTTPS
  # - The iframe.src response includes X-Frame-Options = DENY or SAMEORIGIN
  def verify_oembed_html
    return if self.data[:raw][:oembed][:html].blank?
    html = Nokogiri::HTML self.data[:raw][:oembed][:html]
    self.verify_oembed_html_script(html)
    self.verify_oembed_html_iframe(html)
  end

  def verify_oembed_html_script(html)
    script_tag = html.at_css('script')
    unless script_tag.nil? || script_tag.attr('src').nil?
      uri = URI.parse(script_tag.attr('src'))
      self.data[:raw][:oembed][:html] = '' unless uri.kind_of?(URI::HTTPS)
    end
  end

  def verify_oembed_html_iframe(html)
    iframe_tag = html.at_css('iframe')
    unless iframe_tag.nil? || iframe_tag.attr('src').nil?
      uri = URI.parse(iframe_tag.attr('src'))
      response = Net::HTTP.get_response(uri)
      if !response.nil? && response.code == '200'
        if ['DENY', 'SAMEORIGIN'].include? response.header['X-Frame-Options']
          self.data[:raw][:oembed][:html] = ''
        end
      end
    end
  end
end
