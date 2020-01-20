module MediaTiktokProfile
  extend ActiveSupport::Concern

  TIKTOK_PROFILE_URL = /^https?:\/\/(www\.)?tiktok\.com\/(?<username>[^\/\?]+)/

  included do
    Media.declare('tiktok_profile', [TIKTOK_PROFILE_URL])
  end

  def data_from_tiktok_profile
    match = self.url.match(TIKTOK_PROFILE_URL)
    self.url = match[0]
    username = match['username']

    handle_exceptions(self, StandardError) do
      self.data.merge!(self.data_from_html_metadata)

      self.data.merge!({
        username: username,
        external_id: username,
        title: data['title'],
        picture: data['image'],
        author_picture: data['image'],
        author_name: data['title'],
        author_url: self.url,
        url: self.url
      })
    end
  end
end
