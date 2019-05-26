module MediaOembed
  extend ActiveSupport::Concern

  def get_oembed_data(original_url = nil, maxwidth = nil, maxheight= nil)
    url = original_url || self.url
    if !self.data['raw'].nil? && !self.data['raw']['oembed'].nil?
      self.data['raw']['oembed'].merge(width: maxwidth, height: maxheight, html: Media.default_oembed_html(url, maxwidth, maxheight))
    else
      self.as_json if self.data.empty?
      %w(type provider).each { |key| self.data[key] = self.send(key.to_sym) }
      self.data['raw']['oembed'] = Media.default_oembed(self.data, url, maxwidth, maxheight) unless self.data_from_oembed_item
    end
    self.data['author_name'] ||= self.data.dig('raw', 'oembed', 'author_name')
    self.data['raw']['oembed']
  end

  module ClassMethods
    def as_oembed(data, original_url, maxwidth, maxheight, instance = nil)
      return instance.send(:get_oembed_data, original_url, maxwidth, maxheight) if instance
      if data[:raw].nil? || data[:raw][:oembed].nil?
        Media.default_oembed(data, original_url, maxwidth, maxheight)
      else
        data[:raw][:oembed].merge(width: maxwidth, height: maxheight, html: Media.default_oembed_html(original_url, maxwidth, maxheight))
      end
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
  end
end
