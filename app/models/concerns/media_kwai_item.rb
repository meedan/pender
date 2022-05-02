module MediaKwaiItem
  extend ActiveSupport::Concern

  KWAI_URL = /^https?:\/\/([^.]+\.)?(kwai\.com|kw\.ai)\//

  included do
    Media.declare('kwai_item', [KWAI_URL])
  end

  def data_from_kwai_item
    handle_exceptions(self, StandardError) do
      self.data_from_oembed_item
      self.doc ||= self.get_html({ allow_redirections: :all })
      title = self.get_kwai_text_from_tag('.info .title')
      name = self.get_kwai_text_from_tag('.name')
      data = {
        title: title,
        description: title,
        author_name: name,
        username: name
      }
      self.data ||= {}
      self.data.merge!(data)
    end
  end

  def get_kwai_text_from_tag(selector)
    self.doc&.at_css(selector)&.text&.to_s.strip
  end
end
