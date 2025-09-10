module MediaOembed
  extend ActiveSupport::Concern

  module ClassMethods
    def default_oembed(data, original_url, maxwidth = nil, maxheight= nil)
      maxwidth ||= 800
      maxheight ||= 200
      src = original_url.gsub('medias.oembed', 'medias.html')
      {
        type: 'rich',
        version: '1.0',
        title: data['title'].blank? ? 'Pender' : data['title'],
        author_name: data['author_name'],
        author_url: (data['type'] === 'profile' ? data['url'] : data['author_url']),
        provider_name: data['provider'],
        provider_url: data['url'].present? ? 'http://' + RequestHelper.parse_url(data['url']).host : '',
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

  def get_oembed_data(original_url = nil, maxwidth = nil, maxheight= nil)
    url = original_url || self.url
    if self.provider == 'file'
      self.data['oembed'] = Media.default_oembed(self.data, url, maxwidth, maxheight)
    elsif Media.valid_raw_oembed?(self.data)
      self.data['oembed'] = self.data['raw']['oembed'].merge(width: maxwidth, height: maxheight, html: Media.default_oembed_html(url, maxwidth, maxheight))
    else
      self.process_and_return_json if self.data.empty?
      self.data['oembed'] = get_raw_oembed_data(url) || Media.default_oembed(self.data, url, maxwidth, maxheight)
    end
    self.data['author_name'] ||= self.data.dig('raw', 'oembed', 'author_name')
    self.data['oembed']
  end

  private

  def get_raw_oembed_data(url)
    return if self.data[:error]

    raw_oembed_data = OembedItem.new(url, self.parser.oembed_url(self.doc)).get_data
    self.data.deep_merge!(raw_oembed_data)

    if Media.valid_raw_oembed?(raw_oembed_data)
      self.data[:raw][:oembed]
    end
  end
end
