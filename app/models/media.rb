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

  def as_json(options = {})
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
