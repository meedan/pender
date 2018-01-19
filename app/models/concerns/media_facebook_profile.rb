module MediaFacebookProfile
  extend ActiveSupport::Concern

  included do
    Media.declare('facebook_profile',
      [
        /^https?:\/\/([^\.]+\.)?facebook\.com\/(pages|people)\/([^\/]+)\/([^\/\?]+).*$/,
        /^https?:\/\/(www\.)?facebook\.com\/profile\.php\?id=([0-9]+).*$/,
        /^https?:\/\/([^\.]+\.)?facebook\.com\/(?!(permalink\.php|story\.php|photo\.php|livemap))([^\/\?]+)\/?(\?.*)*$/
      ]
    )
  end

  def facebook_user_fields
    fields = %w(
      link        name                first_name     id            last_name    picture              timezone
      albums      books               events         family        games        groups               likes
      movies      music               photos         tagged_places television   videos               feed
      about       age_range           birthday       cover         currency     education            website
      email       favorite_athletes   favorite_teams gender        hometown     inspirational_people interested_in
      is_verified languages           locale         location      middle_name  name_format          political
      quotes      relationship_status religion       sports        updated_time verified
    )
    fields
  end

  def facebook_page_fields
    fields = %w(
      id                  about            awards         bio              birthday             built                 can_checkin
      category            category_list    checkins       company_overview contact_address      context               country_page_likes
      cover               current_location description    display_subtext  emails               founded               general_info
      general_manager     genre            hometown       hours            is_community_page    photos                is_published
      is_unclaimed        is_verified      keywords       leadgen_tos_accepted link             location              picture
      name                network          new_like_count parent_page      personal_info        phone                 press_contact
      talking_about_count username         voip_info      website          were_here_count      written_by            events
      likes               locations
    )
    fields << 'fan_count' if CONFIG['facebook_api_version'].to_s === 'v2.6'
    fields
  end

  def facebook_client
    Koala.config.api_version = CONFIG['facebook_api_version'] || 'v2.5'
    Koala::Facebook::API.new CONFIG['facebook_auth_token']
  end

  def get_data_from_facebook
    data = {}
    id = self.get_facebook_id_from_url
    client = self.facebook_client
    self.data[:raw][:api] = {}
    # Try to parse as a user profile first
    begin
      object = client.get_object(id, { fields: self.facebook_user_fields }, { method: 'post' })
      self.data[:raw][:api] = object
      data['subtype'] = 'user'
    # If it fails, try to parse as a page
    rescue
      object = client.get_object(id, { fields: self.facebook_page_fields }, { method: 'post' })
      self.data[:raw][:api] = object
      data['subtype'] = 'page'
    end
    data['published_at'] = ''
    data
  end

  def data_from_facebook_profile
    handle_exceptions(self, Koala::Facebook::ClientError, :fb_error_message, :fb_error_code) do
      begin
        self.data.merge! self.get_data_from_facebook
      rescue Koala::Facebook::ClientError => e
        Rails.logger.info "[Facebook Profile] Parsing `#{url}`: Error Code: #{e.fb_error_code} Subcode #{e.fb_error_subcode} Message: #{e.fb_error_message}"
        Airbrake.notify(e) if Airbrake.configuration.api_key && e.fb_error_code == 190
        raise e
      end
    end
    self.get_facebook_likes
    self.data.merge!({
      username: self.get_facebook_username,
      title: get_info_from_data('api', data, 'name'),
      description: get_info_from_data('api', data, 'bio', 'about', 'description'),
      author_url: get_info_from_data('api', data, 'link'),
      author_picture: self.facebook_picture,
      author_name: get_info_from_data('api', data, 'name'),
      picture: self.facebook_picture
    })
  end

  def get_facebook_likes
    likes = self.data['raw']['api']['likes'].to_s
    self.data['likes'] = likes.match(/^[0-9]+$/).nil? ? self.data['raw']['api']['fan_count'] : likes
  end

  def facebook_picture
    data = self.data['raw']['api']
    picture = ''
    if data['picture'] && data['picture']['data'] && data['picture']['data']['url']
      picture = data['picture']['data']['url']
    end
    picture
  end

  def get_facebook_username
    patterns = [
      /^https?:\/\/([^\.]+\.)?facebook\.com\/people\/([^\/\?]+)/,
      /^https:\/\/(www\.)?facebook\.com\/([0-9]+)$/,
      /^https?:\/\/(www\.)?facebook\.com\/([^\/\?]+)/
    ]
    username = compare_patterns(URI.decode(self.url), patterns)
    return if ['events', 'livemap', 'live'].include? username
    if username === 'pages'
      username = self.url.match(/^https?:\/\/(www\.)?facebook\.com\/pages\/([^\/]+)\/([^\/\?]+).*/)[2]
    elsif username.to_i > 0 || username === 'profile.php'
      username = self.data['raw']['api']['name']
    end
    username
  end

  def get_facebook_id_from_url
    self.url = self.original_url if self.url.match(/^https:\/\/www\.facebook\.com\/login\.php\?/)
    uri = Media.parse_url(self.url)
    id = IdsPlease::Grabbers::Facebook.new(self.original_url, Media.request_uri(uri).body.to_s).grab_link.network_id.to_i
    if id === 0
      patterns = [
        /^https:\/\/(www\.)?facebook\.com\/profile\.php\?id=([0-9]+)$/,
        /^https:\/\/(www\.)?facebook\.com\/([0-9]+)$/,
        /^https?:\/\/([^\.]+\.)?facebook\.com\/people\/[^\/\?]+\/([0-9]+)$/
      ]
      id = compare_patterns(self.url, patterns).to_i
    end
    id
  end

  def compare_patterns(url, patterns)
    patterns.each do |p|
      match = url.match p
      return match[2] unless match.nil?
    end
    nil
  end
end
