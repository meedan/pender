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

    private

    # Main function for class
    def parse_data_for_parser(doc, _original_url, _jsonld)
      handle_exceptions(StandardError) do
        select_metatags = { title: 'og:title', picture: 'og:image', description: 'og:description' }
        @parsed_data.merge!(get_metadata_from_tags(select_metatags))
        @parsed_data['title'] = get_title_from_url(url) if parsed_data['title'].blank?
        @parsed_data['description'] = 'Shared with Dropbox' if parsed_data['description'].blank?
      end
      parsed_data
    end

    def get_title_from_url(url)
      uri = RequestHelper.parse_url(url)
      RequestHelper.decode_uri(uri.path.split('/').last)
    end
  end
end
