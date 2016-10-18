module MediaPageItem
  extend ActiveSupport::Concern

  included do
    Media.declare('page_item', [/^.*$/])
  end

  def data_from_page_item
    self.data = self.page_get_data_from_url
  end

  def get_page_html
    options = { allow_redirections: :safe }
    credentials = self.page_get_http_auth(URI.parse(self.url))
    options[:http_basic_authentication] = credentials
    Nokogiri::HTML(open(self.url, options))
  end

  def page_get_data_from_url
    doc = self.get_page_html
    data = {}
    %w(basic oembed opengraph twitter).each do |meta|
      data.merge!(self.send("get_#{meta}_metadata", doc))
    end
    data
  end

  def get_twitter_metadata(doc)
    metatags = { title: 'twitter:title', picture: 'twitter:image', description: 'twitter:description', username: 'twitter:creator' }
    data = get_html_metadata(doc, 'property', metatags)
    data['author_url'] = 'https://twitter.com/' + twitter_data['username'] if data['username']
    data
  end

  def get_opengraph_metadata(doc)
    metatags = { title: 'og:title', picture: 'og:image', description: 'og:description', username: 'article:author', published_at: 'article:published_time' }
    get_html_metadata(doc, 'property', metatags)
  end

  def get_oembed_metadata(doc)
    data = self.data_from_oembed_item(doc)
    self.provider = 'oembed' if data
    data || {}
  end

  def get_basic_metadata(doc)
    metatags = { title: 'title',  description: 'description', username: 'author' }
    data = get_html_metadata(doc, 'name', metatags)
    data[:title] ||= doc.at_css("title").content || ''
    data[:description] ||= data[:title]
    data[:username] ||= ''
    data[:published_at] = ''

    uri = URI.parse(self.url)
    data[:author_url] = "#{uri.scheme}://#{uri.host}"

    data
  end

  def get_html_metadata(doc, attr, metatags)
    data = {}
    metatags.each do |key, value|
      metatag = doc.at_css("meta[#{attr}='#{value}']")
      data[key] = metatag.attr('content') if metatag
    end
    data
  end

  def page_get_http_auth(uri)
    credentials = nil
    unless CONFIG['hosts'].nil?
      config = CONFIG['hosts'][uri.host]
      unless config.nil?
        credentials = config['http_auth'].split(':')
      end
    end
    credentials
  end

end

