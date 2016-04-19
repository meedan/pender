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
        parsed_at: Time.now
      }).with_indifferent_access
    end
  end

  def as_oembed(original_url, maxwidth, maxheight)
    maxwidth ||= 600
    maxheight ||= 300
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
      html: "<iframe src=\"#{src}\" width=\"#{maxwidth}\" height=\"#{maxheight}\" scrolling=\"no\" seamless>Not supported</iframe>",
      width: maxwidth, 
      height: maxheight
    }.with_indifferent_access
  end
  
  include MediaYoutubeProfile
  include MediaTwitterProfile
  include MediaFacebookProfile

  protected

  def get_id
    Digest::MD5.hexdigest(self.url)
  end

  def parse
    self.data = {}
    TYPES.each do |type, patterns|
      patterns.each do |pattern|
        unless pattern.match(self.url).nil?
          self.provider, self.type = type.split('_')
          self.send("data_from_#{type}")
          break
        end
      end
    end
  end
end
