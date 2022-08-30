module Parser
  class DropboxItem < Base
    class << self
      def type
        'dropbox_item'.freeze
      end
  
      def patterns
        [
          /^https?:\/\/(www\.)?dropbox\.com\/sh?\/([^\/]+)/,
          /^https?:\/\/([^\.]+\.)?(dropboxusercontent|dropbox)\.com\/s\/([^\/]+)/,
        ]
      end
    end
  
    def parse_data(doc, _ = nil)
      handle_exceptions(StandardError) do
        metatags = { title: 'og:title', picture: 'og:image', description: 'og:description' }
        @parsed_data.merge!(get_html_metadata(doc, metatags))
        @parsed_data['title'] = get_title_from_url(url) if parsed_data['title'].blank?
        @parsed_data['description'] = 'Shared with Dropbox' if parsed_data['description'].blank?
      end
      parsed_data
    end
  
    private
  
    def get_title_from_url(url)
      uri = URI.parse(url)
      URI.unescape(uri.path.split('/').last)
    end
  end
end
