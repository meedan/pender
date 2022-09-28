module ProviderTiktok
  extend ActiveSupport::Concern

  def oembed_url(_ = nil)
    "https://www.tiktok.com/oembed?url=#{self.url}"
  end
end
