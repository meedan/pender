module Parser
  class TwitterItem < Base
    include ProviderTwitter

    TWITTER_ITEM_URL = /^https?:\/\/([^\.]+\.)?twitter\.com\/((%23|#)!\/)?(?<user>[^\/]+)\/status\/(?<id>[0-9]+).*/

    class << self
      def type
        'twitter_item'.freeze
      end
  
      def patterns
        [TWITTER_ITEM_URL]
      end
    end

    private

    # Main function for class
    def parse_data_for_parser(_doc, _original_url, _jsonld_array)
      @url.gsub!(/(%23|#)!\//, '')
      @url = replace_subdomain_pattern(url)
      parts = url.match(TWITTER_ITEM_URL)
      user, id = parts['user'], parts['id']
      
      @parsed_data['raw']['api'] = {}
      handle_twitter_exceptions do
        @parsed_data['raw']['api'] = TwitterClient.tweet_lookup(id)
      end
      @parsed_data[:error] = parsed_data.dig(:raw, :api, :error)
      @parsed_data.merge!({
        external_id: id,
        username: '@' + user,
        title: parsed_data['raw']['api']['data'][0]['text'] || stripped_title(parsed_data),
        description: parsed_data['raw']['api']['data'][0]['text'] || parsed_data.dig('raw', 'api', 'text') || parsed_data.dig('raw', 'api', 'full_text'),
        picture: parsed_data['raw']['api']['description'] || picture_url(parsed_data),
        author_picture: parsed_data['raw']['api']['includes']['users'][0]['profile_image_url'] || author_picture_url(parsed_data),
        published_at: parsed_data['raw']['api']['data'][0]['created_at'] || parsed_data.dig('raw', 'api', 'created_at'),
        html: html_for_twitter_item(parsed_data, url),
        author_name: parsed_data['raw']['api']['includes']['users'][0]['name'] || parsed_data.dig('raw', 'api', 'user', 'name'),
        author_url: parsed_data['raw']['api']['includes']['users'][0]['url'] || twitter_author_url(user) || RequestHelper.top_url(url)
      })
      parsed_data
    end

    def stripped_title(data)
      title = (data.dig('raw', 'api', 'text') || data.dig('raw', 'api', 'full_text'))
      title.gsub(/\s+/, ' ') if title
    end

    def author_picture_url(data)
      picture_url = data.dig('raw', 'api', 'user', 'profile_image_url_https')
      picture_url.gsub('_normal', '') if picture_url
    end

    def picture_url(data)
      item_media = data.dig('raw', 'api', 'entities', 'media')
      (item_media.dig(0, 'media_url_https') || item_media.dig(0, 'media_url')) if item_media
    end

    def html_for_twitter_item(data, url)
      return '' unless data.dig(:raw, :api, :error).blank?
      '<blockquote class="twitter-tweet">' +
      '<a href="' + url + '"></a>' +
      '</blockquote>' +
      '<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>'
    end
  end
end
