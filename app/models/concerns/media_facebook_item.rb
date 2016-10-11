module MediaFacebookItem
  extend ActiveSupport::Concern

  EVENT_URL =  /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/events\/(?<id>[0-9]+).*/

  URLS = [
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/posts\/(?<id>[0-9]+).*/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/photos\/a\.([0-9]+)\.([0-9]+)\.([0-9]+)\/([0-9]+).*/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/photo.php\?fbid=(?<id>[0-9]+)&set=a\.([0-9]+)\.([0-9]+)\.([0-9]+).*/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/photo.php\?fbid=(?<id>[0-9]+)&set=p\.([0-9]+).*/,
    /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/videos\/(?<id>[0-9]+).*/,
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
      self.data['uuid'] = self.data['user_uuid'] + '_' + self.data['object_id']
    else
      self.data['uuid'] = self.data['object_id']
      self.data['picture'] = 'https://graph.facebook.com/' + self.data['object_id'] + '/picture'
    end
  end

  def get_facebook_user_id_from_url
    return unless self.url.match(EVENT_URL).nil?
    user_id = IdsPlease.new(self.url).grab[:facebook].first.network_id
    if user_id.blank?
      uri = URI.parse(self.url)
      params = CGI.parse(uri.query)
      user_id = params['set'].first.split('.').last
    end
    self.data['user_uuid'] = user_id
    self.data['picture'] = 'https://graph.facebook.com/' + user_id + '/picture'
  end

  def get_facebook_post_id_from_url
    uri = URI.parse(self.url)
    id = uri.path.split('/').last
    if id === 'photo.php'
      params = CGI.parse(uri.query)
      id = params['fbid'].first
    end
    self.data['object_id'] = id
  end

  def get_object_from_facebook(*fields)
    fields = "fields=#{fields.join(',')}&" unless fields.blank?
    uri = URI("https://graph.facebook.com/v2.6/#{self.data['uuid']}?#{fields}access_token=#{CONFIG['facebook_auth_token']}")
    response = Net::HTTP.get_response(uri)
    if response.code.to_i === 200
      JSON.parse(response.body)
    else
      nil
    end
  end

  def parse_from_facebook_api
    fields = ['id', 'type']
    fields += if self.url.match(EVENT_URL).nil?
      ['message', 'created_time', 'from', 'story', 'full_picture', 'source']
    else
      ['owner', 'updated_time', 'description', 'name']
    end
    object = self.get_object_from_facebook(fields)
    if object.nil?
      false
    else
      self.data['text'] = object['message'] || object['story'] || object['description'] || ''
      self.data['published'] = object['created_time'] || object['updated_time']
      self.data['user_name'] = object['name'] || object['from']['name']
      self.data['user_uuid'] = object['owner']['id'] unless self.url.match(EVENT_URL).nil?

      self.parse_facebook_media(object)

      true
    end
  end

  def parse_facebook_media(object)
    media_count = 0
    media_count = 1 if object['type'] === 'photo'
    story = object['story'].to_s.match(/.* added ([0-9]+) new photos.*/)
    media_count = story[1].to_i unless story.nil?
    picture = object['full_picture']
    self.data['photos'] = picture.blank? ? [] : [picture]
    self.data['media_count'] = media_count
    self.data['videos'] = [object['source']] if object['type'] === 'video'
  end

  def parse_from_facebook_html
    doc = self.get_facebook_html
    self.get_facebook_text_from_html(doc)
    text = doc.to_s.gsub(/<[^>]+>/, '')
    media = text.match(/added ([0-9]+) new photos/)
    self.data['media_count'] = media.nil? ? 0 : media[1].to_i
    time = doc.at_css('span.timestampContent')
    self.data['published'] = Time.parse(time.inner_html) unless time.nil?
    self.data['photos'] = []
  end

  def get_facebook_html
    html = ''
    # We need to hack the user agent, otherwise Facebook will return a "unsupported browser" page
    open(@url, 'User-Agent' => 'Mozilla/5.0 (Windows NT 5.2; rv:2.0.1) Gecko/20100101 Firefox/4.0.1', 'Accept-Language' => 'en', 'Cookie' => self.set_cookies) do |f|
      html = f.read
    end
    Nokogiri::HTML html.gsub('<!-- <div', '<div').gsub('div> -->', 'div>')
  end

  def get_facebook_text_from_html(doc)
    content = doc.at_css('div.userContent') || doc.at_css('span.hasCaption')
    f = File.open('/tmp/bli', 'w+'); f.puts(doc.to_s); f.close
    text = content.nil? ? doc.at_css('meta[name=description]').attr('content') : content.inner_html.gsub(/<[^>]+>/, '')
    self.data['text'] = text.to_s.gsub('See Translation', ' ')
    user_name = doc.to_s.match(/ownerName:"([^"]+)"/)
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

  # First method
  def data_from_facebook_item
    self.parse_facebook_uuid
    self.parse_from_facebook_html unless self.parse_from_facebook_api
    self.data['text'].strip!
    self.data['media_count'] = 1 unless self.url.match(/photo\.php/).nil?

    self.data.merge!({
      username: self.data['user_name'],
      title: self.data['user_name'] + ' on Facebook',
      description: self.data['text'] || self.data['description'],
      picture: self.data['picture'] || self.data['photos'].first,
      published_at: self.data['published'],
      html: self.html_for_facebook_post,
      author_url: 'http://facebook.com/' + self.data['user_uuid']
    })
  end
end
