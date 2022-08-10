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

    # Set defaults
    self.set_data_field('external_id', username)
    self.set_data_field('username', username)
    self.set_data_field('title', username)
    self.set_data_field('description', self.url)

    handle_exceptions(self, StandardError) do
      reparse_if_default_tiktok_page
      metatags = { picture: 'og:image', title: 'twitter:creator', description: 'description' }
      data.merge! get_html_metadata(self, metatags)
      self.set_data_field('author_name', data['title'], username)
      self.data.merge!({
        author_picture: data['picture'],
        author_url: self.url,
        url: self.url
      })
    end
  end

  def reparse_if_default_tiktok_page
    if self.doc.css('title').text == 'TikTok'
      self.doc = self.get_html(Media.html_options(self.url), true)
      self.send(:get_metatags, self)
    end
  end
end
