module MediaFacebookItem
  extend ActiveSupport::Concern

  EVENT_URL = /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/events\/(?<id>[0-9]+)(?!.*permalink\/)/

  URLS = [
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/posts\/(?<id>[0-9]+).*/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/photos\/.*a\.([0-9]+)\.([0-9]+)\.([0-9]+)\/([0-9]+).*/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/photos\/pcb\.([0-9]+)\/(?<id>[0-9]+).*/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/photo.php\?fbid=(?<id>[0-9]+)&set=a\.([0-9]+)\.([0-9]+)\.([0-9]+).*/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/photo.php\?fbid=(?<id>[0-9]+)&set=p\.([0-9]+).*/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/videos\/(?<id>[0-9]+).*/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/videos\/vb\.([0-9]+)\/(?<id>[0-9]+).*/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/permalink.php\?story_fbid=(?<id>[0-9]+)&id=([0-9]+).*/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/story.php\?story_fbid=(?<id>[0-9]+)&id=([0-9]+).*/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/livemap(\/.*)?/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/events\/(?<id>[0-9]+)\/permalink\/([0-9]+).*/,
    /^https?:\/\/(www\.)?facebook\.com\/([^\/\?]+).*$/,
    EVENT_URL
  ]

  included do
    Media.declare('facebook_item', URLS)
  end

  def parse_facebook_uuid
    self.url = self.url.gsub(/:\/\/m\.facebook\./, '://www.facebook.')
    self.get_facebook_post_id_from_url
    self.get_facebook_user_id_from_url
    if self.url.match(EVENT_URL).nil?
      self.data['uuid'] = [self.data['user_uuid'], self.data['object_id']].reject(&:empty?).join('_')
    else
      self.data['uuid'] = self.data['object_id']
      get_facebook_picture(self.data['object_id'])
    end
  end

  def get_facebook_user_id_from_url
    return unless self.url.match(EVENT_URL).nil?
    user_id = IdsPlease.new(self.url).grab[:facebook].first.network_id
    if user_id.blank?
      uri = URI.parse(self.url)
      params = parse_uri(uri)
      user_id = params['set'].first.split('.').last unless params['set'].blank?
      user_id ||= params['id'].first.match(/([0-9]+).*/)[1] unless params['id'].blank?
    end
    self.data['user_uuid'] = user_id || ''
    get_facebook_picture(user_id)
  end

  def get_facebook_post_id_from_url
    uri = URI.parse(self.url)
    id = uri.path.split('/').last
    mapping = { 'photo.php' => 'fbid', 'permalink.php' => 'story_fbid', 'story.php' => 'story_fbid', 'set' => 'set', 'photos' => 'album_id' }
    id = self.get_facebook_post_id_from_uri_params(id, uri, mapping[id]) if mapping.keys.include?(id)
    id = '' if id === 'livemap'
    self.data['object_id'] = id.sub(/:0$/, '') if id
  end

  def get_facebook_post_id_from_uri_params(id, uri, key)
    params = parse_uri(uri)
    if id == 'photos' && params.empty?
      self.url = self.original_url
      uri = URI.parse(self.original_url)
      params = parse_uri(uri)
    end
    return '' if params.empty?
    post_id = params[key].first
    post_id = post_id.split('.')[1] if id == 'set'
    post_id
  end

  def parse_uri(uri)
    CGI.parse(uri.query.to_s)
  end

  def get_object_from_facebook(*fields)
    fields = "fields=#{fields.join(',')}&" unless fields.blank?
    uri = URI("https://graph.facebook.com/v2.6/#{self.data['uuid']}?#{fields}access_token=#{CONFIG['facebook_auth_token']}")
    response = Net::HTTP.get_response(uri)
    if response.code.to_i === 200
      JSON.parse(response.body)
    else
      Airbrake.notify(Exception.new(response.body)) if Airbrake.configuration.api_key
      nil
    end
  end

  def parse_from_facebook_api
    object = self.get_object_from_facebook(api_fields)
    if object.nil?
      false
    else
      self.data['text'] = get_text_from_object(object)
      self.data['published_at'] = object['created_time'] || object['updated_time']
      self.data['user_name'] = object['name'] || object['from']['name']
      if self.url.match(EVENT_URL).nil?
        self.data['user_uuid'] = object['from']['id'] if self.data['user_uuid'].blank?
        get_facebook_picture(self.data['user_uuid'])
      else
        self.data['user_uuid'] = object['owner']['id']
      end
      get_url_from_object(object)

      self.parse_facebook_media(object)

      true
    end
  end

  def api_fields
    fields = ['id', 'type']
    if self.url.match(EVENT_URL).nil?
      fields += ['message', 'created_time', 'from', 'story', 'full_picture', 'link', 'permalink_url']
    else
      fields += ['owner', 'updated_time', 'description', 'name']
    end
    fields
  end

  def get_text_from_object(object)
    object['message'] || object['story'] || object['description'] || ''
  end

  def get_url_from_object(object)
    return unless ['video', 'photo', 'status'].include?(object['type'])
    self.url = if object['type'] == 'video'
                 object['link']
               elsif object['type'] == 'status'
                 object['permalink_url']
               elsif object['type'] == 'photo'
                 object['permalink_url'].match(/album\.php/) ? object['link'] : object['permalink_url']
               end
    normalize_url
  end

  def get_facebook_picture(id)
    return if id.blank?
    self.data['picture'] = self.data['author_picture'] = 'https://graph.facebook.com/' + id + '/picture'
  end

  def parse_facebook_media(object)
    external_gif = parse_gif_from_external_link(object)
    media_count = 0
    media_count = 1 if object['type'] === 'photo' || external_gif
    story = object['story'].to_s.match(/.* added ([0-9]+) new photos.*/)
    media_count = story[1].to_i unless story.nil?
    picture = external_gif || object['full_picture']
    self.data['photos'] = picture.blank? ? [] : [picture]
    self.data['media_count'] = media_count
  end

  def parse_gif_from_external_link(object)
    return unless object['type'] === 'link'
    if object['link'].match(/^https?:\/\/([^\.]+\.)?(giphy\.com|gph\.is)\/.*/)
      self.data['link'] = object['link']
      uri = URI.parse(object['full_picture'])
      params = parse_uri(uri)
      params['url'].first
    end
  end

  def parse_from_facebook_html
    self.doc = self.get_html(html_options)
    self.get_facebook_text_from_html
    text = self.doc.to_s.gsub(/<[^>]+>/, '')

    media = text.match(/added ([0-9]+) new photos/)
    self.data['media_count'] = media.nil? ? 0 : media[1].to_i
    time = self.doc.at_css('span.timestampContent')
    self.data['published_at'] = Time.parse(time.inner_html) unless time.nil?
    self.data['photos'] = []
  end

  def get_facebook_text_from_html
    content = self.doc.at_css('div.userContent') || self.doc.at_css('span.hasCaption')
    f = File.open('/tmp/bli', 'w+'); f.puts(self.doc.to_s); f.close
    if content.nil?
      meta_description = self.doc.at_css('meta[name=description]')
      text = meta_description ? meta_description.attr('content') : ''
    else
      text = content.inner_html.gsub(/<[^>]+>/, '')
    end
    self.data['text'] = text.to_s.gsub('See Translation', ' ')
    user_name = self.doc.to_s.match(/ownerName:"([^"]+)"/)
    permalink = self.doc.to_s.match(/permalink:"([^"]+)"/)

    self.url = absolute_url(permalink[1]) if permalink
    self.data['user_name'] = user_name.nil? ? 'Not Identified' : user_name[1]
  end

  def html_for_facebook_post
    '<script>
    window.fbAsyncInit = function() {
      FB.init({
        xfbml      : true,
        version    : "v2.6"
      });
      FB.Canvas.setAutoGrow();
    }; 
    (function(d, s, id) {
      var js, fjs = d.getElementsByTagName(s)[0];
      if (d.getElementById(id)) return;
      js = d.createElement(s); js.id = id;
      js.src = "//connect.facebook.net/en_US/sdk.js";
      fjs.parentNode.insertBefore(js, fjs);
    }(document, "script", "facebook-jssdk"));
    </script>
    <div class="fb-post" data-href="' + self.url + '"></div>'
  end

  def get_facebook_slug_from_html
    username = self.doc.to_s.match(/"username":"([^"]+)"/) || self.doc.to_s.match(/entity:{url:"https:\/\/www\.facebook\.com\/([^"]+)",id:#{self.data['user_uuid']}/)
    self.data['username'] = username[1] unless username.nil?
  end

  # First method
  def data_from_facebook_item
    handle_exceptions(RuntimeError) do
      self.parse_facebook_uuid
      self.parse_from_facebook_html unless self.parse_from_facebook_api
      self.data['text'].strip!
      self.data['media_count'] = 1 unless self.url.match(/photo\.php/).nil?
      self.data.merge!({
        username: self.get_facebook_slug_from_html || self.data['user_name'],
        title: self.data['user_name'] + ' on Facebook',
        description: self.data['text'] || self.data['description'],
        picture: self.data['picture'] || self.data['photos'].first,
        html: self.html_for_facebook_post,
        author_url: 'http://facebook.com/' + self.data['user_uuid']
      })
    end
  end
end
