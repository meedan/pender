module MediaInstagramProfile
  extend ActiveSupport::Concern

  INSTAGRAM_PROFILE_URL = /^https?:\/\/(www\.)?instagram\.com\/([^\/]+)/

  included do
    Media.declare('instagram_profile', [INSTAGRAM_PROFILE_URL])
  end

  def data_from_instagram_profile
    username = self.url.match(INSTAGRAM_PROFILE_URL)[2]
    data = self.data_from_instagram_html
    self.data.merge!(data)
    self.data.merge!({
      username: username,
      title: username,
      picture: data['image'],
      published_at: ''
    })
  end

  def data_from_instagram_html
    data = {}
    %w(image title description).each do |meta|
      data[meta] = self.doc.at_css("meta[property='og:#{meta}']").attr('content')
    end
    data
  end
end 
