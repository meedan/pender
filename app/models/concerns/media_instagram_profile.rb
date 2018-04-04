module MediaInstagramProfile
  extend ActiveSupport::Concern

  INSTAGRAM_PROFILE_URL = /^https?:\/\/(www\.)?instagram\.com\/([^\/]+)/

  included do
    Media.declare('instagram_profile', [INSTAGRAM_PROFILE_URL])
  end

  def data_from_instagram_profile
    username = self.url.match(INSTAGRAM_PROFILE_URL)[2]

    handle_exceptions(self, StandardError) do
      self.data.merge!(self.data_from_instagram_html)
    end

    self.data.merge!({
      username: '@' + username,
      title: username,
      picture: data['image'],
      author_picture: data['image'],
      author_name: get_instagram_author_name || username,
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

  def get_instagram_author_name
    author_name = self.doc.to_s.match(/"full_name": "([^"]+)"/)
    return author_name[1] unless author_name.nil?
  end
end 
