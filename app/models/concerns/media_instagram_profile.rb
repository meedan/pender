module MediaInstagramProfile
  extend ActiveSupport::Concern

  INSTAGRAM_PROFILE_URL = /^https?:\/\/(www\.)?instagram\.com\/([^\/]+)/

  included do
    Media.declare('instagram_profile', [INSTAGRAM_PROFILE_URL])
  end

  def data_from_instagram_profile
    username = self.url.match(INSTAGRAM_PROFILE_URL)[2]

    handle_exceptions(self, RuntimeError) do
      self.data.merge!(self.data_from_instagram_html)
    end

    self.data.merge!({
      username: username,
      title: username,
      picture: data['image'],
      published_at: ''
    })
  end

  def data_from_instagram_html
    raise 'Could not parse this media' if self.doc.blank?
    data = {}
    metatags = { image: 'og:image', title: 'og:title', description: 'og:description' }
    data.merge! get_html_metadata(self, 'property', metatags)
    data
  end
end 
