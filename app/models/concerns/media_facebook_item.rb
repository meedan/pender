module MediaFacebookItem
  extend ActiveSupport::Concern

  EVENT_URL = /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/events\/(?<id>\w+)(?!.*permalink\/)/

  URLS = [
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/posts\/(?<id>[0-9]+).*/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/photos\/.*a\.([0-9]+)\.([0-9]+)\.([0-9]+)\/([0-9]+).*/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/photos\/pcb\.([0-9]+)\/(?<id>[0-9]+).*/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/photo(.php)?\/?\?fbid=(?<id>[0-9]+)&set=a\.([0-9]+)(\.([0-9]+)\.([0-9]+))?.*/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/photo(.php)?\?fbid=(?<id>[0-9]+)&set=p\.([0-9]+).*/,
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

  attr_accessor :shared_content, :metadata

  def parse_facebook_uuid
    self.url = self.url.gsub(/:\/\/m\.facebook\./, '://www.facebook.')
    self.doc ||= self.get_html(Media.extended_headers(self.url))
    self.get_facebook_post_id_from_url
    self.get_facebook_user_id
    if self.url.match(EVENT_URL).nil?
      self.data['uuid'] = [self.data['user_uuid'].to_s, self.data['object_id'].to_s].reject(&:empty?).join('_')
    else
      self.data['uuid'] = self.data['object_id']
      get_facebook_picture(self.data['object_id'])
    end
  end

  def get_facebook_user_id
    return unless self.url.match(EVENT_URL).nil?
    user_id = IdsPlease::Grabbers::Facebook.new(self.url, Media.request_url(self.url).body.to_s).grab_link.network_id
    self.set_data_field('user_uuid', user_id, get_facebook_user_id_from_url)
    get_facebook_picture(self.data['user_uuid'])
  end

  def get_facebook_user_id_from_url
    uri = Media.parse_url(self.url)
    params = parse_uri(uri)
    user_id = params['set'].first.split('.').last unless params['set'].blank?
    user_id ||= params['id'].first.match(/([0-9]+).*/)[1] unless params['id'].blank?
    user_id || self.doc.to_s.match(/"groupID":"(\d+)"/) && self.doc.to_s.match(/"groupID":"(\d+)"/)[1]
  end

  def get_facebook_post_id_from_url
    uri = Media.parse_url(self.url)
    parts = uri.path.split('/')
    id = parts.last
    id = parts[parts.size - 2] if id == 'posts'
    mapping = { 'photo.php' => 'fbid', 'photo' => 'fbid', 'permalink.php' => 'story_fbid', 'story.php' => 'story_fbid', 'set' => 'set', 'photos' => 'album_id' }
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

  def get_facebook_picture(id = '')
    return if id.blank?
    self.data['author_picture'] = 'https://graph.facebook.com/' + id + '/picture'
  end

  def parse_from_facebook_html
    return if self.doc.nil?
    ['photos_from_html', 'info_from_metadata', 'author_name_from_html', 'text_from_html', 'owner_name_from_html', 'user_info_from_html', 'published_time_from_html', 'media_count_from_html', 'url_from_html'].each { |info| self.send("get_facebook_#{info}") }
  end

  def get_facebook_metadata
    get_metatags(self)
    og_metadata = self.get_opengraph_metadata || {}
    tt_metadata = self.get_twitter_metadata || {}
    self.metadata = og_metadata.merge(tt_metadata)
  end

  def get_facebook_info_from_metadata
    metadata = get_facebook_metadata
    self.set_data_field('text', self.get_facebook_description_from_html, metadata['description'])
    self.data['photos'] << metadata['picture'] unless metadata['picture'].blank?
  end

  def get_facebook_description_from_html
    if self.url.match(EVENT_URL).nil?
      text = self.doc.to_s.match(/message":{"text":([^}]+)[^"]+"/)
      text[1] if text
    else
      self.doc.css('span[data-testid="event-permalink-details"]').text
    end
  end

  def get_facebook_author_name_from_html
    author_link = self.doc.at_css('.fbPhotoAlbumActionList a') || self.doc.at_css('.uiHeaderTitle a[href^="https://"]') || self.doc.css('div.userContentWrapper').at_css('h5 > span.fwn.fcg > span.fwb.fcg > a') || self.doc.at_css('.userContentWrapper .profileLink')
    self.set_data_field('author_name', author_link && author_link.text, self.get_facebook_title_from_html, self.metadata['author_name'], self.metadata['title'], self.data['username'])
  end

  def get_facebook_title_from_html
    title = self.doc.at_css('#pageTitle') || self.doc.at_css('title')
    (title && title.text != 'Facebook') ? title.text : ''
  end

  def get_facebook_photos_from_html
    self.data['photos'] = []
    ['.scaledImageFitHeight', '.scaledImageFitWidth'].each { |k| self.data['photos'].concat(self.doc.css(k).collect{ |i| i['src'] }) }
    ['div[data-pagelet="MediaViewerPhoto"] img'].each { |p| self.data['photos'].concat(self.doc.css(p).collect { |i| i['src'] })}
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
    self.set_data_field('user_uuid', user_uuid && user_uuid[1])
    self.get_facebook_picture(self.data['user_uuid']) if !self.data['user_uuid'].blank? && self.data['picture'].blank?
  end

  def get_facebook_owner_name_from_html
    self.get_facebook_event_info_from_html
    user_name = self.doc.to_s.match(/"?ownerName"?:"([^"]+)"/)
    self.set_data_field('author_name', user_name && user_name[1], 'Not Identified')
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
    elsif self.doc.css('abbr').find { |x| x.attr('data-utime')}
      tag = self.doc.css('abbr').find { |x| x.attr('data-utime')}
      self.data['published_at'] = Time.at(tag.attr('data-utime').to_i)
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
      self.data['media_count'] = (self.data['photos'] - [self.metadata['picture'].to_s]).size if self.data['media_count'] == 0
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
      self.get_crowdtangle_data(:facebook)
      self.set_data_field('username', self.get_facebook_username || self.data['author_name'])
      self.parse_from_facebook_html unless [:author_name, :username, :author_picture, :author_url, :description, :text, :external_id, :object_id, :picture, :published_at].map { |key| data[key].blank? }.all?
      self.data['text'].strip! if self.data['text']
      self.set_data_field('author_name', 'Not Identified')
      self.set_data_field('title', self.data['author_name'])
      self.data['title'] += ' on Facebook'
      self.set_data_field('author_url', 'http://facebook.com/' + (self.data['user_uuid'] || self.data['username']).to_s)
      self.get_original_post
      replace_facebook_url(self.data[:username])
      self.set_data_field('external_id', self.data['object_id'])
      self.set_data_field('description', get_facebook_description)
      self.set_data_field('picture', self.data['photos'] && self.data['photos'].first)
      self.data[:html] = self.html_for_facebook_post(self.data[:username])
    end
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
end
