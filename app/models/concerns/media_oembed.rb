module MediaOembed
  extend ActiveSupport::Concern

  def get_oembed_data(original_url = nil, maxwidth = nil, maxheight= nil)
    url = original_url || self.url
    if Media.valid_raw_oembed?(self.data)
      self.data['oembed'] = self.data['raw']['oembed'].merge(width: maxwidth, height: maxheight, html: Media.default_oembed_html(url, maxwidth, maxheight))
    else
      self.as_json if self.data.empty?
      %w(type provider).each { |key| self.data[key] = self.send(key.to_sym) }
      self.data['oembed'] = self.data_from_oembed_item ? self.data['raw']['oembed'] : Media.default_oembed(self.data, url, maxwidth, maxheight)
    end
    self.data['author_name'] ||= self.data.dig('raw', 'oembed', 'author_name')
    self.data['oembed']
  end

  module ClassMethods
    def as_oembed(data, original_url, maxwidth, maxheight, instance = nil)
      return instance.send(:get_oembed_data, original_url, maxwidth, maxheight) if instance
      !Media.valid_raw_oembed?(data) ? Media.default_oembed(data, original_url, maxwidth, maxheight) : data[:oembed].merge(width: maxwidth, height: maxheight, html: Media.default_oembed_html(original_url, maxwidth, maxheight))
    end

    def default_oembed(data, original_url, maxwidth = nil, maxheight= nil)
      maxwidth ||= 800
      maxheight ||= 200
      src = original_url.gsub('medias.oembed', 'medias.html')
      {
        type: 'rich',
        version: '1.0',
        title: data['title'] || 'Pender',
        author_name: data['username'],
        author_url: (data['type'] === 'profile' ? data['url'] : ''),
        provider_name: data['provider'],
        provider_url: 'http://' + Media.parse_url(data['url']).host,
        thumbnail_url: data['picture'],
        html: Media.default_oembed_html(src, maxwidth, maxheight),
        width: maxwidth,
        height: maxheight
      }.with_indifferent_access
    end

    def default_oembed_html(src, maxwidth = 800, maxheight = 200)
      "<iframe src=\"#{src}\" width=\"#{maxwidth}\" height=\"#{maxheight}\" scrolling=\"no\" border=\"0\" seamless>Not supported</iframe>"
    end

    def valid_raw_oembed?(data)
      !data.dig('raw').nil? && !data.dig('raw', 'oembed').nil? && data.dig('raw', 'oembed', 'error').nil?
    end
  end
end
