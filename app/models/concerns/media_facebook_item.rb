module MediaFacebookItem
  extend ActiveSupport::Concern

  EVENT_URL = /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/events\/(?<id>\w+)(?!.*permalink\/)/

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
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/watch(\/.*)?/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/live\/map(\/.*)?/,
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
    user_id = IdsPlease::Grabbers::Facebook.new(self.url, Media.request_url(self.url).body.to_s).grab_link.network_id
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
    parts = uri.path.split('/')
    id = parts.last
    id = parts[parts.size - 2] if id == 'posts'
    mapping = { 'photo.php' => 'fbid', 'permalink.php' => 'story_fbid', 'story.php' => 'story_fbid', 'set' => 'set', 'photos' => 'album_id' }
    id = self.get_facebook_post_id_from_uri_params(id, uri, mapping[id]) if mapping.keys.include?(id)
    id = '' if ['watch', 'livemap', 'map'].include?(id)
    self.data['object_id'] = id.sub(/:0$/, '') if id
  end

  def get_facebook_post_id_from_uri_params(id, uri, key)
    params = parse_uri(uri)
    if id == 'photos' && params.empty?
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

  def get_facebook_picture(id)
    return if id.blank?
    self.data['author_picture'] = 'https://graph.facebook.com/' + id + '/picture'
  end

  def parse_from_facebook_html
    self.doc = self.get_html(Media.html_options(self.url))
    return if self.doc.nil?
    self.get_facebook_info_from_metadata
    self.get_facebook_text_from_html
    self.get_facebook_owner_name_from_html
    self.get_facebook_user_info_from_html
    self.get_facebook_published_time_from_html
    self.get_facebook_media_count_from_html
    self.get_facebook_url_from_html
  end

  def get_facebook_info_from_metadata
    get_metatags(self)
    og_metadata = self.get_opengraph_metadata || {}
    tt_metadata = self.get_twitter_metadata || {}
    metadata = og_metadata.merge(tt_metadata)
    self.data['metadata'] = metadata
    self.data['author_name'] = metadata['title'].nil? ? self.get_facebook_author_name_from_html : metadata['title']
    self.data['text'] = metadata['description'].nil? ? self.get_facebook_description_from_html : metadata['description']
    self.data['photos'] = metadata['picture'].nil? ? self.get_facebook_photos_from_html : [metadata['picture']]
  end

  def get_facebook_description_from_html
    self.doc.css('span[data-testid="event-permalink-details"]').text unless self.url.match(EVENT_URL).nil?
  end

  def get_facebook_author_name_from_html
    author_link = self.doc.at_css('.fbPhotoAlbumActionList a') || self.doc.at_css('.uiHeaderTitle > a')
    author_link.blank? ? self.get_facebook_title_from_html : author_link.text
  end

  def get_facebook_title_from_html
    self.doc.css('#pageTitle').text
  end

  def get_facebook_photos_from_html
    photos = self.doc.css('.scaledImageFitHeight').collect{ |i| i['src'] }
    photos
  end

  def get_facebook_content_from_html
    self.doc.at_css('div.userContent') || self.doc.at_css('span.hasCaption')
  end

  def get_facebook_text_from_html
    return unless self.data['text'].blank? && !self.doc.nil?
    content = self.get_facebook_content_from_html
    text = content.nil? ? self.get_facebook_text_from_meta : content.inner_html.gsub(/<[^>]+>/, '')
    self.data['text'] = text.to_s.gsub('See Translation', ' ')
  end

  def get_facebook_text_from_meta
    meta_description = self.doc.at_css('meta[name=description]')
    text = meta_description ? meta_description.attr('content') : ''
    if text.blank?
      caption = self.doc.at_css('.fbPhotoCaptionText')
      text = caption.text if caption
    end
    text
  end

  def get_facebook_user_info_from_html
    user_uuid = self.doc.to_s.match(/"entity_id":"([^"]+)"/)
    self.data['user_uuid'] = user_uuid[1] if self.data['user_uuid'].blank? && !user_uuid.nil?
    self.get_facebook_picture(self.data['user_uuid']) if !self.data['user_uuid'].blank? && self.data['picture'].blank?
  end

  def get_facebook_owner_name_from_html
    event_name = self.get_facebook_event_name_from_html
    current_name = self.data['author_name']
    user_name = self.doc.to_s.match(/"?ownerName"?:"([^"]+)"/)
    self.data['author_name'] = event_name.nil? ? (user_name.nil? ? (current_name.blank? ? 'Not Identified' : current_name) : user_name[1]) : event_name
  end

  def get_facebook_event_name_from_html
    event_name = self.doc.at_css('div[data-testid="event_permalink_feature_line"]')
    event_name.nil? ? nil : event_name.attr('content')
  end

  def get_facebook_published_time_from_html
    return if self.doc.nil?
    time = self.doc.css('div.userContentWrapper').at_css('span.timestampContent')
    self.data['published_at'] = verify_published_time(time.inner_html, time.parent.attr('data-utime')) unless time.nil?
  end

  def get_facebook_url_from_html
    permalink = self.doc.to_s.match(/permalink:"([^"]+)"/)
    self.url = absolute_url(permalink[1]) if permalink
  end

  def get_facebook_media_count_from_html
    media = self.doc.css('a > div.uiScaledImageContainer')
    if media.empty? && !self.url.match(/\/photos\//).nil?
      self.data['media_count'] = 1
    else
      self.data['media_count'] = media.empty? ? 0 : media.size
      self.data['media_count'] = (self.data['photos'] - [self.data['metadata']['picture']]).size if self.data['media_count'] == 0
    end
  end

  def render_facebook_embed?(username)
    privacy_error = self.get_facebook_privacy_error(self.doc) if self.doc
    self.data['error'] = privacy_error if privacy_error
    !['groups', 'flx'].include?(username) && !privacy_error && self.url.match(EVENT_URL).nil?
  end

  def html_for_facebook_post(username)
    return '' unless render_facebook_embed?(username)
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

  # First method
  def data_from_facebook_item
    ## Screenshots are disabled
    # self.screenshot_script = 'function closeLoginModal(){if(document.getElementById("headerArea")){document.getElementById("headerArea").style.display="none";}else{setTimeout(closeLoginModal,1000);}}closeLoginModal();'
    handle_exceptions(self, StandardError) do
      self.parse_facebook_uuid
      self.parse_from_facebook_html
      description = self.data['text'] || self.data['description']
      description.gsub!(/\s+/, ' ')
      self.data['text'].strip! if self.data['text']
      self.data['media_count'] = 1 unless self.url.match(/photo\.php/).nil?
      self.data['author_name'] = 'Not Identified' if self.data['author_name'].blank?
      self.get_original_post
      username = self.get_facebook_username || self.data['author_name']
      self.data.merge!({
        external_id: self.data['object_id'],
        username: username,
        title: self.data['author_name'] + ' on Facebook',
        description: description,
        picture: self.set_facebook_picture,
        html: self.html_for_facebook_post(username),
        author_name: self.data['author_name'],
        author_url: 'http://facebook.com/' + self.data['user_uuid'].to_s
      })
    end
  end

  def get_original_post
    return if self.doc.nil?
    sharing_info = self.doc.css('div.userContentWrapper').at_css('h5 > span.fwn > span.fcg')
    if sharing_info && sharing_info.text.match(/shared a/) && sharing_info.at_css('span.fwb')
      original_post = absolute_url(sharing_info.css('> a').attr('href'))
      media = Media.new(url: original_post)
      data = media.as_json
      self.data['original_post'] = data['url']
      self.data['picture'] = data['picture']
    end
  end

  def set_facebook_picture
    return self.data['picture'] unless self.data['picture'].blank?
    self.data['photos'].nil? ? '' : self.data['photos'].first
  end

  def facebook_oembed_url
    uri = Media.parse_url(self.url)
    "https://www.facebook.com/plugins/post/oembed.json/?url=#{uri}"
  end
end
