class ApiKey < ApplicationRecord
  validates_presence_of :access_token, :expire_at
  validates_uniqueness_of :access_token

  before_validation :generate_access_token, on: :create
  before_validation :calculate_expiration_date, on: :create
  
  serialize :application_settings

  # Reimplement this method in your application
  def self.applications
    [nil]
  end

  def self.current
    RequestStore.store[:api_key]
  end

  def self.current=(api_key)
    RequestStore.store[:api_key] = api_key
  end
  
  validates :application, inclusion: { in: proc { ApiKey.applications } }

  def settings
    self.application_settings ? self.application_settings.with_indifferent_access : {}
  end

  private

  def generate_access_token
    loop do
      self.access_token = SecureRandom.hex
      break unless ApiKey.where(access_token: access_token).exists?
    end
  end

  def calculate_expiration_date
    self.expire_at = Time.now.since(30.days)
  end
end
