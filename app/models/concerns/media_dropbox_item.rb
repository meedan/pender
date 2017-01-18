module MediaDropboxItem
  extend ActiveSupport::Concern

  URLS = [
    /^https?:\/\/(www\.)?dropbox\.com\/s\/([^\/]+)/,
    /^https?:\/\/(dl\.)?dropboxusercontent\.com\/s\/([^\/]+)/
  ]

  included do
    Media.declare('dropbox_item', URLS)
  end

  def data_from_dropbox_item
    handle_exceptions(RuntimeError) do
      self.parse_from_dropbox_html
      self.data.merge!({
        html: html_for_dropbox_item,
      })
    end
  end

  def parse_from_dropbox_html
    metatags = { title: 'og:title', picture: 'og:image', description: 'og:description' }
    data.merge!(get_html_metadata('property', metatags))
    data.merge!(get_html_metadata('name', { title: 'title' })) unless data['title'].blank?
    self.data['author_url'] = 'http://www.dropbox.com'
  end

  def dropbox_dl
    self.url.gsub(/:\/\/www\.dropbox\./, '://dl.dropbox.')
  end

  def html_for_dropbox_item
    '<object data="' + dropbox_dl + '"></object>'
  end

end
