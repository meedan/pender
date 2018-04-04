module MediaDropboxItem
  extend ActiveSupport::Concern

  URLS = [
    /^https?:\/\/(www\.)?dropbox\.com\/sh?\/([^\/]+)/,
    /^https?:\/\/(dl\.)?dropboxusercontent\.com\/s\/([^\/]+)/
  ]

  included do
    Media.declare('dropbox_item', URLS)
  end

  def data_from_dropbox_item
    handle_exceptions(self, StandardError) do
      self.parse_from_dropbox_html
      self.data['title'] = get_title_from_url if data['title'].blank?
      self.data['description'] = 'Shared with Dropbox' if data['description'].blank?
    end
  end

  def parse_from_dropbox_html
    metatags = { title: 'og:title', picture: 'og:image', description: 'og:description' }
    data.merge!(get_html_metadata(self, 'property', metatags))
  end

  def get_title_from_url
    uri = URI.parse(self.url)
    uri.path.split('/').last
  end

end
