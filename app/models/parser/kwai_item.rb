module Parser
  class KwaiItem < Base
    KWAI_URL = /^https?:\/\/([^.]+\.)?(kwai\.com|kw\.ai)\//
  
    class << self
      def type
        'kwai_item'.freeze
      end
  
      def patterns
        [KWAI_URL]
      end
    end

    private    

    # Main function for class
    def parse_data_for_parser(doc, _original_url, jsonld_array)
      handle_exceptions(StandardError) do
        jsonld = (jsonld_array.find{|item| item.dig('@type') == 'VideoObject'} || {})

        title = get_kwai_text_from_tag(doc, '.info .title') 
        name = get_kwai_text_from_tag(doc, '.name') || jsonld.dig('creator','name')&.strip
        description = get_kwai_text_from_tag(doc, '.info .title') || jsonld.dig('transcript')&.strip || jsonld.dig('description')&.strip
        @parsed_data.merge!({
          title: title,
          description: description,
          author_name: name,
          username: name
        })
      end

      parsed_data
    end
  
    def get_kwai_text_from_tag(doc, selector)
      doc&.at_css(selector)&.text&.to_s&.strip
    end
  end
end
