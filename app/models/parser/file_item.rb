module Parser
  class FileItem < Base
    class FileReceivedException < StandardError; end

    FILE_ITEM_URL = /^.*\.(?<ext>png|gif|jpg|jpeg|bmp|tif|tiff|pdf|mp3|mp4|ogg|mov|csv|svg|wav)$/i

    class << self
      def type
        'file_item'.freeze
      end

      def patterns
        [FILE_ITEM_URL]
      end
    end

    private

    # Main function for class
    def parse_data_for_parser(_doc, _original_url, _jsonld)
      parsed_data
    end
  end
end
