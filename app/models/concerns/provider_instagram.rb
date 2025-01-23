module ProviderInstagram
  extend ActiveSupport::Concern

  class ApiError < StandardError; end

  def get_instagram_data_from_apify(url)
    Media.apify_request(url, :instagram)
  end

  class_methods do
    def ignored_urls
      [
        {
          pattern: /^https:\/\/(www\.)?instagram\.com/,
          reason: :login_page
        },
        {
          pattern: /^https:\/\/www\.instagram\.com\/accounts\/login/,
          reason: :login_page
        },
        {
          pattern: /^https:\/\/www\.instagram\.com\/login\//,
          reason: :login_page
        },
        {
          pattern: /^https:\/\/www\.instagram\.com\/challenge\//,
          reason: :account_challenge_page
        },
        {
          pattern: /^https:\/\/www\.instagram\.com\/privacy\/checks/,
          reason: :privacy_check_page
        },
      ]
    end
  end

  def oembed_url(_ = nil)
    request_url = self.url

    request_url = request_url.sub(/\?.*/, '')
    request_url = request_url + "/" unless request_url.end_with? "/"

    '<div><iframe src="' + request_url + 'embed" width="397" height="477" frameborder="0" scrolling="no" allowtransparency="true"></iframe></div>'
  end
end
