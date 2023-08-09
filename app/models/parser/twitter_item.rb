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
      @url.gsub!(/\s/, '')
      @url = replace_subdomain_pattern(url)
      
      parts = url.match(TWITTER_ITEM_URL)
      user, id = parts['user'], parts['id']
      
      @parsed_data['raw']['api'] = tweet_lookup(id)

      @parsed_data[:error] = parsed_data['raw']['api']['errors']

      if @parsed_data[:error] 
        title = url
        description = ''
        picture = ''
        author_picture = ''
        published_at = ''
        html = ''
        author_name = user
        author_url = get_author_url(user)
      elsif @parsed_data[:error].nil?
        raw_data = parsed_data['raw']['api']['data'][0]
        raw_user_data = parsed_data['raw']['api']['includes']['users'][0]

        title = raw_data['text'].squish
        description = title
        picture = get_twitter_item_picture(parsed_data)
        author_picture = raw_user_data['profile_image_url'].gsub('_normal', '')
        published_at = raw_data['created_at']
        html = html_for_twitter_item(url)
        author_name = raw_user_data['name']
        author_url = get_author_url(user) || raw_user_data['url'] || RequestHelper.top_url(url)
      end
 
      @parsed_data.merge!({
        external_id: id,
        username: '@' + user,
        title: title,
        description: description,
        picture: picture,
        author_picture: author_picture,
        published_at: published_at,
        html: html,
        author_name: author_name,
        author_url: author_url
      })
      parsed_data
    end

    def get_author_url(user)
      'https://twitter.com/' + user
    end

    def get_twitter_item_picture(parsed_data)
      media = parsed_data['raw']['api']['includes']['media']
      media.nil? ? nil : media[0]['url']
    end

    def html_for_twitter_item(url)
      '<blockquote class="twitter-tweet">' +
      '<a href="' + url + '"></a>' +
      '</blockquote>' +
      '<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>'
    end
  end
end
