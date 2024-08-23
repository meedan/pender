module ProviderFacebook
  extend ActiveSupport::Concern

  NONUNIQUE_TITLES = %w[
    facebook events livemap watch live story.php category photo photo.php profile.php
  ]

  class_methods do
    def ignored_urls
      [
        { pattern: /^https:\/\/([^\.]+\.)?facebook.com\/login/, reason: :login_page },
        { pattern: /^https:\/\/([^\.]+\.)?facebook.com\/?$/, reason: :login_page },
        { pattern: /^https:\/\/([^\.]+\.)?facebook.com\/cookie\/consent-page/, reason: :consent_page }
      ]
    end

    # Extracted from https://github.com/meedan/ids_please/blob/master/lib/ids_please/grabbers/facebook.rb#L29
    # for ease of maintenance
    def get_id_from_doc(html_page)
      html_string = html_page.to_s
      match = html_string.match(/"entity_id"(\s?):(\s?)"(?<id>\d+)"/) ||
        html_string.match(/"al:ios:url"(\s?)content="fb:\/\/page\/\?id=(?<id>\d+)"/) ||
        html_string.match(/"owning_profile"\s?:\s?{\s?"__typename"\s?:\s?"Page"\s?,\s?"id"\s?:\s?"(?<id>\d+)"/)

      match['id'] unless match.nil?
    end
  end

  def oembed_url(_ = nil)
    "https://www.facebook.com/plugins/post/oembed.json/?url=#{RequestHelper.parse_url(self.url)}"
  end

  private

  def get_scrapingbot_data(url)
    response_data = {}
    return { error: { message: 'No URL provided for ScrapingBot', code: Lapis::ErrorCodes::const_get('UNKNOWN') }} if url.blank?

    scrapingbot_data = Media.scrapingbot_request(:facebook_post, url)

    if scrapingbot_data.blank?
      return { error: { message: "No data received from ScrapingBot", code: Lapis::ErrorCodes::const_get('UNKNOWN') }}
    elsif scrapingbot_data.dig('result').blank?
     return { error: { message: "No data received from ScrapingBot", code: Lapis::ErrorCodes::const_get('UNKNOWN') }}
    elsif scrapingbot_data['error'].present?
      return { error: { message: scrapingbot_data['error']['message'], code: Lapis::ErrorCodes::const_get('UNKNOWN') }}
    end


    scrapingbot_data.dig('result')
  end

  def format_scrapingbot_result(data)
    post_info = (data.dig('posts') || []).first
    message = post_info.dig('message')
    picture = (post_info.dig('media').select { |m| m['type'] == 'photo' }.first || {}).dig('full') if post_info.dig('media')

    {
      author_name: post_info.dig('account', 'name'),
      username: post_info.dig('account', 'handle'),
      author_picture: post_info.dig('account', 'profileImage'),
      author_url: post_info.dig('account', 'url'),
      title: message,
      description: message,
      text: message,
      external_id: post_info.dig('platformId'),
      picture: picture,
      published_at: post_info.dig('date'),
      subtype: post_info.dig('type'),
    }.with_indifferent_access
  end

  def has_valid_scrapingbot_data?
    parsed_data.dig('raw', 'scrapingbot').present? && parsed_data.dig('raw', 'scrapingbot', 'error').blank?
  end

  def set_facebook_privacy_error(html_page, page_is_unavailable)
    return if html_page.nil?
    return if has_valid_scrapingbot_data?

    title = get_page_title(html_page)
    return if title.blank?

    ['log in or sign up to view', 'log into facebook', 'log in to facebook'].each do |login|
      if page_is_unavailable || title.downcase.include?(login)
        @parsed_data['title'] = nil
        @parsed_data['description'] = ''
        @parsed_data['error'] = {
          message: 'Login required to see this profile',
          code: Lapis::ErrorCodes::const_get('LOGIN_REQUIRED'),
        }
      return true
      end
    end
  end

  def strip_facebook_from_title!
    return unless @parsed_data['title']

    @parsed_data['title'].gsub!(' | Facebook', '')
  end

  def get_unique_facebook_page_title(html_page)
    title = get_page_title(html_page)
    return unless title
    return if NONUNIQUE_TITLES.include?(title.downcase)

    title
  end
end
