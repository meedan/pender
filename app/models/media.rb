class Media
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming
  
  attr_accessor :url, :provider, :type, :data

  TYPES = {}

  def initialize(attributes = {})
    attributes.each do |name, value|
      send("#{name}=", value)
    end
    self.follow_redirections
    self.normalize_url
    self.data = {}.with_indifferent_access
  end

  def self.declare(type, patterns)
    TYPES[type] = patterns
  end

  def as_json(_options = {})
    Rails.cache.fetch(self.get_id) do
      self.parse
      self.data.merge({
        url: self.url,
        provider: self.provider,
        type: self.type,
        parsed_at: Time.now,
        favicon: "http://www.google.com/s2/favicons?domain_url=#{self.url}" 
      }).with_indifferent_access
    end
  end

  include MediaYoutubeProfile
  include MediaTwitterProfile
  include MediaFacebookProfile
  include MediaOembedItem

  def as_oembed(original_url, maxwidth, maxheight)
    data = self.as_json
    oembed = "#{data['provider']}_as_oembed"
    self.respond_to?(oembed)? self.send(oembed, original_url, maxwidth, maxheight) : self.default_oembed(original_url, maxwidth, maxheight)
  end

  protected

  def default_oembed(original_url, maxwidth, maxheight)
    maxwidth ||= 800
    maxheight ||= 200
    data = self.as_json
    src = original_url.gsub('medias.oembed', 'medias.html')
    {
      type: 'rich',
      version: '1.0',
      title: data['title'] || 'Pender',
      author_name: data['username'],
      author_url: (data['type'] === 'profile' ? data['url'] : ''),
      provider_name: data['provider'],
      provider_url: 'http://' + URI.parse(data['url']).host,
      thumbnail_url: data['picture'],
      html: "<iframe src=\"#{src}\" width=\"#{maxwidth}\" height=\"#{maxheight}\" scrolling=\"no\" border=\"0\" seamless>Not supported</iframe>",
      width: maxwidth, 
      height: maxheight
    }.with_indifferent_access
  end

  def get_id
    Digest::MD5.hexdigest(self.url)
  end

  def parse
    self.data = {}
    parsed = false
    TYPES.each do |type, patterns|
      patterns.each do |pattern|
        unless pattern.match(self.url).nil?
          self.provider, self.type = type.split('_')
          self.send("data_from_#{type}")
          parsed = true
          break
        end
      end
      break if parsed
    end
  end

  def normalize_url
    self.url = PostRank::URI.normalize(self.url).to_s
  end

  def follow_redirections
    self.url = 'http://' + self.url unless self.url =~ /^https?:/
    attempts = 0
    code = '301'
    path = []
    
    while attempts < 5 && code == '301' && !path.include?(self.url)
      attempts += 1
      path << self.url
      response = self.request_media_url
      code = response.code
    
      if code == '301'
        self.url = response.header['location']
      end
    end
  end

  def request_media_url
    uri = URI.parse(self.url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 30
    http.use_ssl = true unless self.url.match(/^https/).nil?
    request = Net::HTTP::Get.new(uri.request_uri)
    http.request(request)
  end
end
