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
    data = {}
    id = self.get_facebook_id_from_url
    # Try to parse as a user profile first
    begin
      self.parse_facebook_user
      data['subtype'] = 'user'
    # If it fails, try to parse as a page
    rescue
      begin
        self.parse_facebook_page
      rescue
        self.parse_facebook_legacy_page
      end
      data['subtype'] = 'page'
    end
    data['published_at'] = ''
    data
  end

  def get_facebook_profile_html
    if @html.nil?
      body = Net::HTTP.get_response(URI(URI.escape(self.url)))
      @html = body.gsub('<!--', '').gsub('-->', '')
    end
    @html
  end

  def parse_facebook_user
    html = self.get_facebook_profile_html
    page = Nokogiri::HTML(html)

    self.data['name'] = page.css('#fb-timeline-cover-name').first.text
    bio = page.css('#pagelet_bio span').last
    self.data['description'] = bio ? bio.text : ''
    self.data['picture'] = page.css('.img.profilePic.img').first.attr('src')
  end

  def parse_facebook_page
    html = self.get_facebook_profile_html
    page = Nokogiri::HTML(html)
    match = html.match(/"name":"([^"]+)","pageID":"([^"]+)","username":([^,]+),"usernameEditDialogProfilePictureURI":"([^"]+)"/)
    json = JSON.parse('{' + match[0] + '}')
    
    self.data['name'] = json['name']
    self.data['username'] = json['username']
    self.data['description'] = page.css('meta[name=description]').first.attr('content').gsub(/.*talking about this. /, '')
    self.data['picture'] = json['usernameEditDialogProfilePictureURI']
  end

  def parse_facebook_legacy_page
    html = self.get_facebook_profile_html
    page = Nokogiri::HTML(html)

    bio = page.css('blockquote .text_exposed_root').first
    self.data['description'] = bio ? bio.text : ''
    pic = page.css('img.scaledImageFitWidth').first
    self.data['picture'] = pic.attr('src') if pic
    name = page.css('.profileLink').first
    self.data['name'] = name.text if name
  end

  def data_from_facebook_profile
    self.data.merge! self.get_data_from_facebook
    self.get_facebook_likes
    self.data.merge!({
      username: self.get_facebook_username,
      title: self.data['name'],
      description: self.data['description'],
      author_url: self.url,
      author_picture: self.data['picture'],
      author_name: self.data['name'],
      picture: self.data['picture']
    })
  end

  def get_facebook_likes
    html = self.get_facebook_profile_html
    page = Nokogiri::HTML(html)
    self.data['likes'] = page.css('#PagesLikesCountDOMID span').text.gsub(/ .*/, '').gsub(/[^0-9]/, '')
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
    uri = Media.parse_url(self.url)
    id = IdsPlease::Grabbers::Facebook.new(self.original_url, Media.request_uri(uri).body.to_s).grab_link.network_id.to_i
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
