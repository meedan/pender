module Parser
  class YoutubeProfile < Base
    include ProviderYoutube

    DIRECT_ATTRIBUTES = %w(
      comment_count
      country
      description
      title
      published_at
      subscriber_count
      video_count
      view_count
      thumbnails
    )

    class << self
      def type
        'youtube_profile'.freeze
      end
  
      def patterns
        [/^https?:\/\/(www\.)?youtube\.com\/(user|channel)\/([^\/]+)/]
      end
    end

    def parse_data(doc)
      @parsed_data[:raw][:api] = {}
      handle_youtube_exceptions do
        Yt.configuration.api_key = PenderConfig.get(:google_api_key)
        channel = Yt::Channel.new url: url
        video_data = channel.snippet.data.with_indifferent_access
        video_statistics = channel.statistics_set.data.with_indifferent_access
        @parsed_data[:raw][:api][:id] = channel.id
        DIRECT_ATTRIBUTES.each do |attr|
          camel_attr = attr.camelize(:lower)
          @parsed_data[:raw][:api][attr] = attr.match('_count') ? video_statistics.dig(camel_attr) : video_data.dig(camel_attr)
        end
        set_data_field('playlists_count', channel.playlists.count)
        set_data_field('country', parsed_data.dig('raw','api','country'))
        set_data_field('video_count', parsed_data.dig('raw','api','video_count'))
        set_data_field('subscriber_count', parsed_data.dig('raw','api','subscriber_count'))
      end
      set_data_field('external_id', parsed_data.dig('raw', 'api', 'id'), get_youtube_channel_id(url))

      metadata = get_opengraph_metadata(doc) || {}
      set_data_field('title', parsed_data.dig('raw','api','title'), metadata.dig('title'))
      set_data_field('description', parsed_data.dig('raw','api','description'), metadata.dig('description'))
      set_data_field('picture', get_youtube_thumbnail(parsed_data), metadata.dig('picture'))
      set_data_field('username', get_youtube_username(url), usernameify(parsed_data[:title]))
      set_data_field('published_at', parsed_data.dig('raw','api','published_at'))
      set_data_field('author_picture', parsed_data[:picture])
      set_data_field('author_name', parsed_data[:title])
      set_data_field('subtype', get_youtube_subtype(url))

      parsed_data
    end

    private

    def get_youtube_channel_id(request_url)
      match = request_url.match(/^https?:\/\/(www\.)?youtube\.com\/channel\/([^\/]+)/)
      match[2] if match
    end

    def get_youtube_username(request_url)
      match = request_url.match(/^https?:\/\/(www\.)?youtube\.com\/user\/([^\/]+)/)
      match[2].downcase if match
    end

    def usernameify(item)
      return unless item
      item.gsub(/[^a-zA-Z0-9]/, '').downcase
    end

    def get_youtube_subtype(request_url)
      match = request_url.match(/^https?:\/\/(www\.)?youtube\.com\/(user|channel)\/([^\/]+)/)
      match[2]
    end
  end
end
