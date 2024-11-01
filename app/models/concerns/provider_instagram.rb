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
end
