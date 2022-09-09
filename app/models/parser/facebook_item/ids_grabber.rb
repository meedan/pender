module Parser
  class FacebookItem::IdsGrabber
    def initialize(doc, request_url, original_url)
      @request_url = request_url
      @original_url = original_url
      @doc = doc

      # Not sure we should parse parseable_url - meant to be a way that we track
      # what URL gets parsed, but is actually pulling weight of parsing right now
      nonmobile_url = @request_url.gsub(/:\/\/m\.facebook\./, '://www.facebook.')
      @parseable_uri = RequestHelper.parse_url(nonmobile_url)

      @post_id = nil
      @user_id = nil
    end

    attr_reader :parseable_uri

    def post_id
      return @post_id if @post_id

      [request_url, original_url].each do |url|
        ::Parser::FacebookItem.patterns.each do |pattern|
          match = pattern.match(url)
          if match && match.names.include?('id') && Integer(match['id'], exception: false)
            @post_id = match ['id']
            return @post_id
          end
        end

        if post_id = post_id_from_params(url)
          @post_id = post_id
          return @post_id
        end
      end
      nil
    end

    def user_id
      return @user_id if @user_id
      return if (request_url.match(Parser::FacebookItem::EVENT_URL) || original_url.match(Parser::FacebookItem::EVENT_URL))

      id_from_html = ::Parser::FacebookItem.get_id_from_doc(doc)
      (@user_id = id_from_html and return @user_id) if id_from_html
      
      # May want to try both request_url and original_url for URL parsing
      # Right now we just try request_url, which may be bad redirect
      user_id_from_url = id_from_params(parseable_uri) ||
        group_id_from_html(doc) || 
        owner_id_from_html(doc) || 
        user_id_from_html(doc) ||
        set_id_from_params(parseable_uri)
      (@user_id = user_id_from_url and return @user_id) if user_id_from_url

      profile_id_from_url = user_id_from_url_pattern(request_url, original_url)
      (@user_id = profile_id_from_url and return @user_id) if profile_id_from_url
      nil
    end

    def uuid
      # UUID must be in format userid_postid
      return unless user_id && post_id

      [user_id.to_s, post_id.to_s].join('_')
    end

    private

    attr_reader :request_url, :original_url, :doc

    def id_from_params(uri)
      params = parse_uri(parseable_uri)
      return unless params['id'].any?
      params['id'].first[/([0-9]+).*/, 1]
    end
    
    def group_id_from_html(html_page)
      html_page.to_s[/"groupID"\s?:\s?"(\d+)"/, 1]
    end

    def owner_id_from_html(html_page)
      match = html_page.to_s.match(/"owner"\s?:\s?(?<json>\{(?:[^{}])*\})/)
      return unless match && match['json']
      JSON.parse(match['json'])['id']
    end

    def user_id_from_html(html_page)
      html_page.to_s[/"userID"\s?:\s?"(\d+)"/, 1]
    end

    def set_id_from_params(uri)
      params = parse_uri(parseable_uri)
      return unless params['set'].any?
      params['set'].first.split('.').last
    end

    def user_id_from_url_pattern(request_url, original_url)
      [request_url, original_url].each do |url|
        ::Parser::FacebookItem.patterns.each do |pattern|
          match = pattern.match(url)
          next unless match

          return match['user_id'] if match.names.include?('user_id') && Integer(match['user_id'], exception: false)
          return match['profile'] if match.names.include?('profile') && Integer(match['profile'], exception: false)
        end
      end
      nil
    end

    # Catch-all for params that our regexes miss
    def post_id_from_params(url)
      uri = RequestHelper.parse_url(url)
      parts = uri.path.split('/')
      id = parts.last
      id = parts[parts.size - 2] if id == 'posts'
      mapping = {
        'photo.php' => 'fbid',
        'photo' => 'fbid',
        'permalink.php' => 'story_fbid',
        'story.php' => 'story_fbid',
        'set' => 'set',
        'photos' => 'album_id'
      }
      return unless mapping.keys.include?(id)
      return if (params = parse_uri(uri)).empty?

      # Get relevant info from a.12345 or 12345:0
      slug = params[mapping[id]].first
      slug[/(\d+)/, 1]
    end

    def parse_uri(uri)
      CGI.parse(uri.query.to_s)
    end
  end
end
