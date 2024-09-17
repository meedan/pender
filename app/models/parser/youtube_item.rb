module Parser
  class YoutubeItem < Base
    include ProviderYoutube

    YOUTUBE_ITEM_URL = /^https?:\/\/(www\.|m\.)?(youtube(-nocookie)?\.com|youtu\.be)\/((watch\?v=|embed\/|v\/|e\/|shorts\/|live\/|playlist\?list=)?(?<id>[a-zA-Z0-9_-]{9,11})([&?]([^#]+))?(#t=[\dhms]+)?)|(oembed\?url=.+)|(attribution_link\?a=.+&u=%2Fwatch%3Fv%3D(?<id>[a-zA-Z0-9_-]{9,11})(.+))$/

    DIRECT_ATTRIBUTES = %w[
      description
      title
      published_at
      thumbnails
      channel_title
      channel_id
      id
    ]

    class << self
      def type
        'youtube_item'.freeze
      end

      def patterns
        [YOUTUBE_ITEM_URL]
      end
    end

    private

    # Main function for class
    def parse_data_for_parser(doc, _original_url, _jsonld_array)
      @parsed_data[:raw][:api] = {}

      handle_youtube_exceptions do
        video = Yt::Video.new url: url
        video_data = video.snippet.data.with_indifferent_access
        DIRECT_ATTRIBUTES.each do |attr|
          @parsed_data[:raw][:api][attr] = video_data.dig(attr.camelize(:lower)) || video.send(attr) || ''
        end
      end

      metadata = get_opengraph_metadata || {}
      set_data_field('title', parsed_data.dig('raw', 'api', 'title'), metadata.dig('title'))
      set_data_field('description', parsed_data.dig('raw', 'api', 'description'), metadata.dig('description'))
      set_data_field('picture', get_thumbnail(parsed_data), metadata.dig('picture'))
      set_data_field('username', parsed_data.dig('raw', 'api', 'channel_title'))
      @parsed_data.merge!({
        external_id: parsed_data.dig('raw', 'api', 'id') || get_channel_id(url),
        html: html_for_youtube_item(parsed_data),
        author_name: parsed_data.dig('raw', 'api', 'channel_title'),
        author_picture: get_author_picture(parsed_data),
        author_url: get_author_url(parsed_data),
        published_at: parsed_data.dig('raw', 'api', 'published_at')
      })
      
      parsed_data
    end

    def get_channel_id(request_url)
      request_url.match(YOUTUBE_ITEM_URL)['id']
    end

    def get_author_url(data)
      cid = data[:raw][:api]['channel_id']
      cid.blank? ? '' : "https://www.youtube.com/channel/#{cid}"
    end

    def get_author_picture(data)
      begin
        channel = Yt::Channel.new id: data[:raw][:api]['channel_id']
        channel.thumbnail_url.to_s
      rescue
        ''
      end
    end

    def html_for_youtube_item(data)
      return '' if data['raw']['api']['channel_id'].blank?
      "<iframe width='480' height='270' src='//www.youtube.com/embed/#{data.dig('raw','api','id')}' frameborder='0' allow='accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture' allowfullscreen></iframe>"
    end
  end
end
