module MediaDropboxItem
  extend ActiveSupport::Concern

  DROPBOX_URL = /^https?:\/\/(www\.)?dropbox\.com\/s\/([^\/]+)/

  included do
    Media.declare('dropbox_item', [DROPBOX_URL])
  end

  def data_from_dropbox_item
    handle_exceptions(RuntimeError) do
      self.parse_from_dropbox_html
      self.url = self.url.gsub(/:\/\/www\.dropbox\./, '://dl.dropbox.')
      self.data.merge!({
        html: html_for_dropbox_item,
      })
    end
  end

  def parse_from_dropbox_html
    self.data['description'] = self.doc.at_css("meta[property='og:description']").attr('content').strip
    self.data['title'] = self.doc.at_css("meta[property='og:title']").attr('content').strip
    self.data['picture'] = self.doc.at_css("meta[property='og:image']").attr('content')
    self.data['author_url'] = top_url(self.url)
  end

  def html_for_dropbox_item
    '<blockquote class="dropbox-item">' +
    '<a href="' + self.url + '"></a>' +
    '</blockquote>' +
    '<script async src="' + self.url + '.js"></script>'
  end

end
