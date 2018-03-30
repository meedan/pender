module MediaBridgeItem
  extend ActiveSupport::Concern

  included do
    Media.declare('bridge_item', [/^https?:\/\/(www\.|new\.)?speakbridge.io\/medias\/embed\/(?<project>[^\/]+)\/[^\/]+\/(?<id>[^\/]+)$/])
  end

  def data_from_bridge_item
    handle_exceptions(self, StandardError) do
      self.parse_from_bridge_html
      self.data.merge!({
        html: html_for_bridge_item,
        author_name: self.data['username'],
        author_picture: self.data['picture']
      })
    end
  end

  def parse_from_bridge_html
    self.data['description'] = self.doc.at_css("meta[property='og:description']").attr('content').strip
    self.data['title'] = self.doc.at_css("meta[property='og:title']").attr('content').strip
    self.data['picture'] = self.doc.at_css("meta[property='og:image']").attr('content')
    get_author
  end

  def get_author
    author = self.doc.at_css('.bridgeEmbed__item-translation a[class=name]')
    self.data['username'] = author.content if author
    self.data['author_url'] = author.attr('href') if author
  end

  def html_for_bridge_item
    '<blockquote class="bridge-item">' +
    '<a href="' + self.url + '"></a>' +
    '</blockquote>' +
    '<script async src="' + self.url + '.js"></script>'
  end
end
