module MediaFacebookProfile
  extend ActiveSupport::Concern

  included do
    Media.declare('facebook_profile',
      [
        /^https?:\/\/([^\.]+\.)?facebook\.com\/(pages|people)\/([^\/]+)\/([^\/\?]+).*$/,
        /^https?:\/\/(www\.)?facebook\.com\/profile\.php\?id=([0-9]+).*$/,
        /^https?:\/\/([^\.]+\.)?facebook\.com\/(?!(permalink\.php|story\.php|photo\.php|livemap))([^\/\?]+)\/?(\?.*)*$/
      ]
    )
  end

  def get_data_from_facebook
    page = self.get_facebook_profile_page

    if page.blank?
      return { error: { message: 'Not Found' } }
    end

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

    error = self.get_facebook_profile_error
    data['error'] = error if error
    
    data['likes'] = self.get_facebook_likes
    
    data['published_at'] = ''
    data
  end

  def get_facebook_profile_error
    page = self.get_facebook_profile_page
    title = page.css('meta[property="og:title"]')
    if title.present? && title.attr('content') && title.attr('content').value == 'Log In or Sign Up to View'
      { message: 'Login required to see this profile' }
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
    self.data.merge! self.get_data_from_facebook
    self.data.merge!({
      username: self.get_facebook_username,
      title: self.get_facebook_name,
      description: self.data['description'],
      author_url: self.url,
      author_picture: self.data['picture'],
      author_name: self.data['name'],
      picture: self.data['picture']
    })
  end

  def get_facebook_name
    page = self.get_facebook_profile_page
    unless page.nil?
      title = page.css('meta[property="og:title"]')
      self.data['name'].blank? ? title.attr('content').value : self.data['name']
    end
  end

  def get_facebook_likes
    page = self.get_facebook_profile_page
    page.css('#PagesLikesCountDOMID span').text.gsub(/ .*/, '').gsub(/[^0-9]/, '')
  end

  def get_facebook_username
    patterns = [
      /^https?:\/\/([^\.]+\.)?facebook\.com\/people\/([^\/\?]+)/,
      /^https:\/\/(www\.)?facebook\.com\/([0-9]+)$/,
      /^https?:\/\/(www\.)?facebook\.com\/([^\/\?]+)/
    ]
    username = compare_patterns(URI.decode(self.url), patterns)
    return if ['events', 'livemap', 'live'].include? username
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
