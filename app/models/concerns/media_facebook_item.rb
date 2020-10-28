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

  attr_accessor :shared_content

  def parse_facebook_uuid
    self.url = self.url.gsub(/:\/\/m\.facebook\./, '://www.facebook.')
    self.get_facebook_post_id_from_url
    self.get_facebook_user_id_from_url
    if self.url.match(EVENT_URL).nil?
      self.data['uuid'] = [self.data['user_uuid'].to_s, self.data['object_id'].to_s].reject(&:empty?).join('_')
    else
      self.data['uuid'] = self.data['object_id']
      get_facebook_picture(self.data['object_id'])
    end
  end

  def get_facebook_user_id_from_url
    return unless self.url.match(EVENT_URL).nil?
    user_id = IdsPlease::Grabbers::Facebook.new(self.url, Media.request_url(self.url).body.to_s).grab_link.network_id
    if user_id.blank?
      uri = Media.parse_url(self.url)
      params = parse_uri(uri)
      user_id = params['set'].first.split('.').last unless params['set'].blank?
      user_id ||= params['id'].first.match(/([0-9]+).*/)[1] unless params['id'].blank?
      unless user_id
        group_id = self.doc.to_s.match(/"groupID":"(\d+)"/)
        user_id ||= group_id[1] if group_id
      end
    end
    self.data['user_uuid'] = user_id || ''
    get_facebook_picture(user_id)
  end

  def get_facebook_post_id_from_url
    uri = Media.parse_url(self.url)
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
    return if self.doc.nil?
    self.get_facebook_info_from_metadata
    self.get_facebook_author_name_from_html
    self.get_facebook_text_from_html
    self.get_facebook_owner_name_from_html
    self.get_facebook_user_info_from_html
    self.get_facebook_published_time_from_html
    self.get_facebook_media_count_from_html
    self.get_facebook_url_from_html
  end

  def get_facebook_metadata
    get_metatags(self)
    og_metadata = self.get_opengraph_metadata || {}
    tt_metadata = self.get_twitter_metadata || {}
    self.data['metadata'] = og_metadata.merge(tt_metadata)
  end

  def get_facebook_info_from_metadata
    metadata = get_facebook_metadata
    self.data['text'] = metadata['description'].nil? ? self.get_facebook_description_from_html : metadata['description']
    self.data['photos'] = metadata['picture'].nil? ? self.get_facebook_photos_from_html : [metadata['picture']]
  end

  def get_facebook_description_from_html
    self.doc.css('span[data-testid="event-permalink-details"]').text unless self.url.match(EVENT_URL).nil?
  end

  def get_facebook_author_name_from_html
    return unless self.data['author_name'].blank?
    author_link = self.doc.at_css('.fbPhotoAlbumActionList a') || self.doc.at_css('.uiHeaderTitle a[href^="https://"]') || self.doc.css('div.userContentWrapper').at_css('h5 > span.fwn.fcg > span.fwb.fcg > a') || self.doc.at_css('.userContentWrapper .profileLink')
    self.data['author_name'] = author_link.blank? ? self.get_facebook_title_from_html : author_link.text
    metadata = self.data['metadata']
    if self.data['author_name'].blank? && metadata['author_name'].nil? && !metadata['title'].nil?
      self.data['author_name'] = metadata['title']
    end
  end

  def get_facebook_title_from_html
    title = self.doc.at_css('#pageTitle') || self.doc.at_css('title')
    title ? title.text : ''
  end

  def get_facebook_photos_from_html
    photos = []
    ['.scaledImageFitHeight', '.scaledImageFitWidth'].each { |k| photos.concat(self.doc.css(k).collect{ |i| i['src'] }) }
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
    self.get_facebook_event_info_from_html
    user_name = self.doc.to_s.match(/"?ownerName"?:"([^"]+)"/)
    self.data['author_name'] ||= (user_name.nil? ? 'Not Identified' : user_name[1])
  end

  def get_facebook_event_info_from_html
    author_name = self.doc.at_css('h1[data-testid="event-permalink-event-name"]')
    self.data['title'] = author_name.content if author_name.respond_to?(:content)
    author = self.doc.at_css('div#event_header_primary a.profileLink')
    if author
      self.data['author_name'] = author.content
      self.data['author_url'] = author.attr('href')
    end
  end

  def get_facebook_published_time_from_html
    return if self.doc.nil?
    timestamp = self.doc.to_s.match(/\\"publish_time\\":([0-9]+)/)
    if timestamp
      self.data['published_at'] = Time.at(timestamp[1].to_i)
    elsif self.doc.at_css('abbr.timestamp')
      self.data['published_at'] = Time.at(self.doc.at_css('abbr.timestamp').attr('data-utime').to_i)
    else
      time = self.doc.css('div.userContentWrapper').at_css('span.timestampContent') || self.doc.at_css('#MPhotoContent abbr')
      self.data['published_at'] = verify_published_time(time.inner_html, time.parent.attr('data-utime')) unless time.nil?
    end
  end

  def get_facebook_url_from_html
    permalink = self.doc.to_s.match(/permalink:"([^"]+)"/)
    self.url = absolute_url(permalink[1]) if permalink
  end

  def get_facebook_media_count_from_html
    media = self.doc.css('a > div.uiScaledImageContainer')
    if media.empty? && (!self.url.match(/\/photos\//).nil? || !self.url.match(/photo\.php/).nil?)
      self.data['media_count'] = 1
    else
      self.data['media_count'] = media.empty? ? 0 : media.size
      self.data['media_count'] = (self.data['photos'] - [self.data['metadata']['picture']]).size if self.data['media_count'] == 0
    end
  end

  def render_facebook_embed?(username)
    privacy_error = self.get_facebook_privacy_error(self.doc) if self.doc
    !['groups', 'flx'].include?(username) && !privacy_error && self.url.match(EVENT_URL).nil?
  end

  def html_for_facebook_post(username)
    return '' unless render_facebook_embed?(username) && !self.doc.nil?
    '<script>
    window.fbAsyncInit = function() { FB.init({ xfbml: true, version: "v2.6" }); FB.Canvas.setAutoGrow(); }; 
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
    handle_exceptions(self, StandardError) do
      self.parse_facebook_uuid
      self.get_crowdtangle_facebook_data(self.data['uuid'])
      self.parse_from_facebook_html unless [:author_name, :username, :author_picture, :author_url, :description, :text, :external_id, :object_id, :picture, :published_at].map { |key| data[key].blank? }.all?
      self.data['text'].strip! if self.data['text']
      self.data['author_name'] = set_facebook_field('author_name', 'Not Identified')
      self.data['title'] = (self.data['title'].blank? ? self.data['author_name'] : self.data['title']) + ' on Facebook'
      self.data['author_url'] = set_facebook_field('author_url', 'http://facebook.com/' + self.data['user_uuid'].to_s)
      self.get_original_post
      self.data['username'] = set_facebook_field('username', self.get_facebook_username || self.data['author_name'])
      replace_facebook_url(self.data[:username])
      self.data['external_id'] = set_facebook_field('external_id', self.data['object_id'])
      self.data['description'] = set_facebook_field('description', get_facebook_description)
      self.data['picture'] = set_facebook_field('picture', self.set_facebook_picture)
      self.data[:html] = self.html_for_facebook_post(self.data[:username])
    end
  end

  def set_facebook_field(field, value)
    return self.data[field] unless self.data[field].blank?
    self.data[field] = value
  end

  def get_original_post
    return if self.doc.nil? || self.shared_content
    link = get_facebook_sharing_info
    if link
      original_post = absolute_url(link)
      media = Media.new(url: original_post, shared_content: true)
      data = media.as_json
      self.data['original_post'] = data['url']
      self.data['picture'] = data['picture']
    end
  end

  def get_facebook_sharing_info
    sharing_info = self.doc.css('div.userContentWrapper .mtm._5pcm').css('div[data-testid="story-subtitle"] .fcg > a')
    return if sharing_info.blank?
    shared_url = sharing_info.attr('href')
    absolute_url(shared_url)
  end

  def set_facebook_picture
    return self.data['picture'] unless self.data['picture'].blank?
    self.data['photos'].nil? ? '' : self.data['photos'].first
  end

  def facebook_oembed_url
    "https://www.facebook.com/plugins/post/oembed.json/?url=#{Media.parse_url(self.url)}"
  end

  def get_facebook_description
    default_description = self.data['text'] || self.data['description']
    post_full_text = self.doc && self.doc.at_css('div[data-testid="post_message"]') ? self.doc.css('div[data-testid="post_message"]').text : nil
    group_post_content = self.doc.to_s.match(/"message":{[^}]+"text":"([^"]+)"/)
    description = group_post_content ? group_post_content[1].gsub('\\n', ' ') : (post_full_text || default_description)
    description.gsub!(/\s+/, ' ')
  end

  def replace_facebook_url(username)
    self.url = self.original_url if username == 'groups'
  end

  def get_crowdtangle_facebook_data(id)
    crowdtangle_data = Media.crowdtangle_request('facebook', id)
    return unless crowdtangle_data && crowdtangle_data['result']
    self.data['raw']['crowdtangle'] = crowdtangle_data['result']
    post_info = crowdtangle_data['result']['posts'].first
    self.data[:author_name] = post_info['account']['name']
    self.data[:username] = post_info['account']['handle']
    self.data[:author_picture] = post_info['account']['profileImage']
    self.data[:author_url] = post_info['account']['url']
    self.data[:description] = self.data[:text] = post_info['message']
    self.data[:external_id] = post_info['platformId']
    self.data[:object_id] = post_info['platformId']
    self.data[:picture] = post_info['media'].first['full'] if post_info['media']
    self.data[:published_at] = post_info['date']
  end
end
