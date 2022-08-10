module MediaInstagramProfile
  extend ActiveSupport::Concern

  INSTAGRAM_PROFILE_URL = /^https?:\/\/(www\.)?instagram\.com\/([^\/]+)/

  included do
    Media.declare('instagram_profile', [INSTAGRAM_PROFILE_URL])
  end

  def data_from_instagram_profile
    username = self.url.match(INSTAGRAM_PROFILE_URL)[2]

    handle_exceptions(self, StandardError) do
      self.set_data_field('username', '@' + username)
      self.set_data_field('title', username)
      self.set_data_field('description', self.url)
      self.data.merge!({ external_id: username })

      response_data = self.get_instagram_api_data(
        "https://i.instagram.com/api/v1/users/web_profile_info/?username=#{username}",
        additional_headers: { 'x-ig-app-id': '936619743392459' }
      )
      return if self.data['error']
      self.data['raw']['api'] = response_data['data']
      # If we use set_data_field, it won't override the default value above
      self.data['description'] = self.data.dig('raw', 'api', 'user', 'biography')
      self.set_data_field('picture', self.data.dig('raw', 'api', 'user', 'profile_pic_url'))
      self.set_data_field('author_name', self.data.dig('raw', 'api', 'user', 'full_name'))
      self.set_data_field('author_picture', self.data.dig('raw', 'api', 'user', 'profile_pic_url'))
      self.set_data_field('published_at', '')
    end
  end
end 
