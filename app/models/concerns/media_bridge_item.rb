module MediaBridgeItem
  extend ActiveSupport::Concern

  included do
    Media.declare('bridge_item', [/^https?:\/\/(www\.)?speakbridge.io\/medias\/embed\/(?<project>[^\/]+)\/[^\/]+\/(?<id>[0-9]+)$/])
  end

  def data_from_bridge_item
    handle_exceptions(RuntimeError) do
      self.parse_from_bridge_html
      self.data.merge!({
        html: html_for_bridge_item,
      })
    end
  end

  def parse_from_bridge_html
    author = self.doc.at_css('.bridgeEmbed__item-translation a[class=name]')
    self.data['username'] = author.content
    self.data['author_url'] = author.attr('href')
    self.data['description'] = self.doc.at_css("meta[property='og:description']").attr('content').strip
    self.data['title'] = self.doc.at_css("meta[property='og:title']").attr('content').strip
    self.data['picture'] = self.doc.at_css("meta[property='og:image']").attr('content')
  end

  def html_for_bridge_item
    '<blockquote class="bridge-item">' +
    '<a href="' + self.url + '"></a>' +
    '</blockquote>' +
    '<script async src="' + self.url + '.js"></script>'
  end
end
