module ProviderFacebook
  extend ActiveSupport::Concern

  class_methods do
    def ignored_urls
      [
        { pattern: /^https:\/\/([^\.]+\.)?facebook.com\/login/, reason: :login_page },
        { pattern: /^https:\/\/([^\.]+\.)?facebook.com\/?$/, reason: :login_page },
        { pattern: /^https:\/\/([^\.]+\.)?facebook.com\/cookie\/consent-page/, reason: :consent_page }
      ]
    end
  end

  private
end
