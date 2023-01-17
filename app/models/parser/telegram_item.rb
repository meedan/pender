module Parser
  class TelegramItem < Base
    include ProviderInstagram

    URL_REGEX = /^https?:\/\/(www\.)?(t|telegram)\.me\/(?<username>[^\/]+)\/(?<id>[0-9]+).*$/

    class << self
      def type
        'telegram_item'.freeze
      end

      def patterns
        [URL_REGEX]
      end
    end

    private

    # Main function for class
    def parse_data_for_parser(doc, _original_url, _jsonld)
      match = url.match(URL_REGEX)
      id = match['id']
      username = match['username']

      set_data_field('title', url)
      set_data_field('description', get_metadata_from_tag('og:description'), get_metadata_from_tag('twitter:description'))
      set_data_field('username', username)
      set_data_field('external_id', match['id'])
      set_data_field('username', match['username'])
      set_data_field('author_name', get_metadata_from_tag('og:title'), get_metadata_from_tag('twitter:title'))
      set_data_field('picture', get_metadata_from_tag('og:image'), get_metadata_from_tag('twitter:image'))

      parsed_data
    end
  end
end
