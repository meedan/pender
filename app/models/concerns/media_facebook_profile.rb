module MediaFacebookProfile
  extend ActiveSupport::Concern

  included do
    Media.declare('facebook_profile',
      [
        /^https?:\/\/([^\.]+\.)?facebook\.com\/(pages|people)\/([^\/]+)\/([^\/\?]+)((?!\/photos\/?).)*$/,
        /^https?:\/\/(www\.)?facebook\.com\/profile\.php\?id=([0-9]+).*$/,
        /^https?:\/\/([^\.]+\.)?facebook\.com\/(?!(permalink\.php|story\.php|photo\.php|livemap|watch))([^\/\?]+)\/?(\?.*)*$/
      ]
    )
  end

  def get_data_from_facebook
    page = self.get_facebook_profile_page

    return if page.blank?

    data = {}
    # Try to parse as a user profile first
    begin
      data = self.parse_facebook_user
      data['subtype'] = 'user'
    # If it fails, try to parse as a page
    rescue
      begin
        data = self.parse_facebook_page
      rescue
        data = self.parse_facebook_legacy_page
      end
      data['subtype'] = 'page'
    end
    data['id'] = self.get_facebook_id_from_url

    self.get_facebook_privacy_error
    
    data['likes'] = self.get_facebook_likes
    
    data['published_at'] = ''
    data
  end

  def get_facebook_privacy_error(doc = nil)
    page = doc || self.get_facebook_profile_page
    title = page.css('meta[property="og:title"]')
    if title.present? && title.attr('content') && title.attr('content').value.downcase == 'log in or sign up to view'
      self.data['error'] = { message: 'Login required to see this profile', code: LapisConstants::ErrorCodes::const_get('LOGIN_REQUIRED') }
      return true
    end
  end

  def get_facebook_profile_html
    if @html.nil?
      @html = self.get_html(Media.html_options(self.url)).to_s
    end
    @html
  end

  def get_facebook_profile_page
    if @page.nil?
      @page = self.get_html(Media.html_options(self.url))
    end
    @page
  end

  def parse_facebook_user
    page = self.get_facebook_profile_page

    data = {}
    data['name'] = page.css('#fb-timeline-cover-name').first.text
    bio = page.css('#pagelet_bio span').last
    desc = page.css('.profileText').last
    data['description'] = bio ? bio.text : (desc ? desc.text : '')
    data['picture'] = page.css('.profilePicThumb img').first.attr('src')
    data
  end

  def parse_facebook_page
    html = self.get_facebook_profile_html
    page = self.get_facebook_profile_page
    match = html.match(/"name":"([^"]+)","pageID":"([^"]+)","username":([^,]+),"usernameEditDialogProfilePictureURI":"([^"]+)"/)
    json = JSON.parse('{' + match[0] + '}')
    
    data = {}
    data['name'] = json['name']
    data['username'] = json['username']
    data['description'] = page.css('meta[name=description]').first.attr('content').gsub(/.*talking about this. /, '')
    data['picture'] = json['usernameEditDialogProfilePictureURI']
    data
  end

  def parse_facebook_legacy_page
    page = self.get_facebook_profile_page

    data = {}
    bio = page.css('blockquote .text_exposed_root').first
    data['description'] = bio ? bio.text : ''
    pic = page.css('img.scaledImageFitWidth').first
    data['picture'] = pic.attr('src') if pic
    name = page.css('.profileLink').first
    name2 = page.css('h1[itemprop=name]').first
    data['name'] = name.text unless name.nil?
    data['name'] = name2.text if name.nil? && !name2.nil?
    data
  end

  def data_from_facebook_profile
    handle_exceptions(self, StandardError) do
      data = self.get_data_from_facebook
      self.data.merge!(data) unless data.nil?
      picture = self.get_value_from_facebook_metatags(self.data['picture'], 'og:image')
      self.data.merge!({
        external_id: self.data['id'] || '',
        username: self.get_facebook_username,
        title: self.get_value_from_facebook_metatags(self.get_facebook_name, 'og:title'),
        description: self.get_value_from_facebook_metatags(self.data['description'], 'og:description'),
        author_url: self.url,
        author_picture: picture,
        author_name: self.data['name'],
        picture: picture
      })
    end
  end

  def get_value_from_facebook_metatags(current, name)
    return current unless current.blank?
    tags = self.data.dig('raw', 'metatags') || []
    value = nil
    tags.each { |tag| value = tag['content'] if tag['property'] == name }
    value
  end

  def get_facebook_name
    return self.data['name'] unless self.data['name'].blank?
    page = self.get_facebook_profile_page
    unless page.nil?
      title = page.css('meta[property="og:title"]')
      if title.present? && title.attr('content')
        title.attr('content').value
      elsif page.at_css('title')
        page.at_css('title').content
      else
        'Facebook'
      end
    end
  end

  def get_facebook_likes
    page = self.get_facebook_profile_page
    page.css('#PagesLikesCountDOMID span').text.gsub(/ .*/, '').gsub(/[^0-9]/, '')
  end

  def get_facebook_username
    return self.data['username'] unless self.data['username'].blank?
    patterns = [
      /^https?:\/\/([^\.]+\.)?facebook\.com\/people\/([^\/\?]+)/,
      /^https:\/\/(www\.)?facebook\.com\/([0-9]+)$/,
      /^https?:\/\/(www\.)?facebook\.com\/([^\/\?]+)/
    ]
    username = compare_patterns(decoded_uri(self.url), patterns)
    return if ['events', 'livemap', 'watch', 'live', 'story.php'].include? username
    if username === 'pages'
      username = self.url.match(/^https?:\/\/(www\.)?facebook\.com\/pages\/([^\/]+)\/([^\/\?]+).*/)[2]
    elsif username.to_i > 0 || username === 'profile.php'
      username = self.data['username']
    end
    username
  end

  def get_facebook_id_from_url
    self.url = self.original_url if self.url.match(/^https:\/\/www\.facebook\.com\/login\.php\?/)
    id = IdsPlease::Grabbers::Facebook.new(self.original_url, Media.request_url(self.url).body.to_s).grab_link.network_id.to_i
    if id === 0
      patterns = [
        /^https:\/\/(www\.)?facebook\.com\/profile\.php\?id=([0-9]+)$/,
        /^https:\/\/(www\.)?facebook\.com\/([0-9]+)$/,
        /^https?:\/\/([^\.]+\.)?facebook\.com\/people\/[^\/\?]+\/([0-9]+)$/
      ]
      id = compare_patterns(self.url, patterns).to_i
    end
    id
  end

  def compare_patterns(url, patterns)
    patterns.each do |p|
      match = url.match p
      return match[2] unless match.nil?
    end
    nil
  end
end
