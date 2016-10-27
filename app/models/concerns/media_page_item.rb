module MediaPageItem
  extend ActiveSupport::Concern

  included do
    Media.declare('page_item', [/^.*$/])
  end

  def data_from_page_item
    self.doc ||= self.get_html
    self.data = self.page_get_data_from_url
    if self.data[:picture].blank?
      generate_screenshot
    end
  end

  def page_get_data_from_url
    raise 'Could not parse this media' if self.doc.blank?
    data = self.data
    %w(basic oembed opengraph twitter).each do |meta|
      data.merge!(self.send("get_#{meta}_metadata")) { |_key, v1, v2| v2.blank? ? v1 : v2 }
    end
    data
  end

  def get_twitter_metadata
    metatags = { title: 'twitter:title', picture: 'twitter:image', description: 'twitter:description', username: 'twitter:creator' }
    data = get_html_metadata('property', metatags)
    data['author_url'] = 'https://twitter.com/' + twitter_data['username'] if data['username']
    data
  end

  def get_opengraph_metadata
    metatags = { title: 'og:title', picture: 'og:image', description: 'og:description', username: 'article:author', published_at: 'article:published_time' }
    get_html_metadata('property', metatags)
  end

  def get_oembed_metadata
    data = self.data_from_oembed_item
    self.provider = 'oembed' if data
    data || {}
  end

  def get_basic_metadata
    metatags = { title: 'title',  description: 'description', username: 'author' }
    data = get_html_metadata('name', metatags)
    data[:title] ||= self.doc.at_css("title").content || ''
    data[:description] ||= data[:title]
    data[:username] ||= ''
    data[:published_at] = ''
    data[:picture] = ''

    uri = URI.parse(URI.encode(self.url))
    data[:author_url] = "#{uri.scheme}://#{uri.host}"
    data
  end

  def get_html_metadata(attr, metatags)
    data = {}
    metatags.each do |key, value|
      metatag = self.doc.at_css("meta[#{attr}='#{value}']")
      data[key] = metatag.attr('content') if metatag
    end
    data
  end

  def generate_screenshot
    base_url = self.request.base_url
    path = self.url.parameterize + '.png'
    output_file = File.join(Rails.root, 'public', 'screenshots', path)
    fetcher = Smartshot::Screenshot.new(window_size: [800, 600])
    if fetcher.take_screenshot! url: self.url, output: output_file, wait_for_element: ['body'], sleep: 10, frames_path: []
      data[:picture] = URI.join(base_url, 'screenshots/', path).to_s
    end
  end
end
