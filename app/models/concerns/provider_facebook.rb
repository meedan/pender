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
        { pattern: /^https:\/\/([^\.]+\.)?facebook.com\/cookie\/consent-page/, reason: :consent_page },
        { pattern: /^https:\/\/([^\.]+\.)?facebook.com\/watch\/*?$/, reason: :watch_page }
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

  def get_apify_data(url)
    response_data = {}
    return { error: { message: 'No URL provided for Apify', code: Lapis::ErrorCodes::const_get('UNKNOWN') }} if url.blank?

    apify_data = Media.apify_request(url)

    if apify_data.blank?
      return { error: { message: "No data received from Apify", code: Lapis::ErrorCodes::const_get('UNKNOWN') }}
    elsif !apify_data.is_a?(Array) && apify_data.dig('result').blank?
      return { error: { message: "No data received from Apify", code: Lapis::ErrorCodes::const_get('UNKNOWN') }}
    elsif apify_data.is_a?(Hash) && apify_data['error'].present?
      return { error: { message: apify_data['errorDescription'], code: Lapis::ErrorCodes::const_get('UNKNOWN') }}
    elsif apify_data.is_a?(Array) && apify_data.first['error'].present?
      return { error: { message: apify_data.first['errorDescription'], code: Lapis::ErrorCodes::const_get('UNKNOWN') }}
    end

    apify_data.is_a?(Array) ? apify_data.first : apify_data
  end

  def format_apify_result(data)
    post_info = (data)

    text = post_info.dig('text')
    title = text || post_info.dig('previewTitle')
    description = text || post_info.dig('previewDescription')
    media = post_info.dig('media')
    picture = item_picture(media)

    user = post_info.dig('user')
    user_name = item_user_name(user,post_info)
    user_info = user_info(user)

    post_id = post_info.dig('postId')
    {
      author_name: user_name,
      username: user_name,
      author_url: user_info[:url],
      author_picture: user_info[:picture],
      title: title,
      description: description,
      text: text,
      external_id: "#{user_info[:id]}_#{post_id}",
      picture: picture,
      published_at: user ? post_info.dig('time').sub('T', ' ').sub('.000Z', '') : "",
    }.with_indifferent_access
  end

  def item_picture(media)
    picture = media.find { |m| m['thumbnail'] }&.dig('thumbnail') || "" if media.is_a?(Array)
    picture || ""
  end

  def item_user_name(user, post_info)
    user_name = user.dig('name') if user.is_a?(Hash)
    user_name ||= post_info.dig('pageName')
    user_name || ""
  end

  def user_info(user)
    if user.is_a?(Hash)
      {
        id: user['id'] || "",
        url: user['profileUrl'] || "",
        picture: user['profilePic'] || ""
      }
    else
      {
         id: "",
         url: "",
         picture: ""
       }
    end
  end

  def has_valid_apify_data?
    parsed_data.dig('raw', 'apify').present? && parsed_data.dig('raw', 'apify', 'error').blank?
  end

  def set_facebook_dead_end_error(html_page, page_is_unavailable)
    return if html_page.nil?
    return if has_valid_apify_data?

    title = get_page_title(html_page)
    return if title.blank?

    login_page = login_page?(title) || page_is_unavailable == :login_page

    if page_is_unavailable || login_page
      @parsed_data['title'] = nil
      @parsed_data['description'] = ''
      @parsed_data['error'] =
        login_page ?
        {
          message: 'Login required to see this profile',
          code: Lapis::ErrorCodes::const_get('LOGIN_REQUIRED'),
        }
        :
        {
          message: 'Redirected to a dead end',
          code: Lapis::ErrorCodes::const_get('DEAD_END'),
        }
      return true
    end
  end

  def login_page?(title)
    login_messages = ['log in or sign up to view', 'log into facebook', 'log in to facebook']
    login_messages.any? { |login_message| title.downcase.include?(login_message)}
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
