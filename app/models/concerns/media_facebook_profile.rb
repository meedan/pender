module MediaFacebookProfile
  extend ActiveSupport::Concern

  included do
    Media.declare('facebook_profile',
      [
        /^https?:\/\/(www\.)?facebook\.com\/([^\/\?]+).*$/,
        /^https?:\/\/(www\.)?facebook\.com\/pages\/([^\/]+)\/([^\/\?]+).*$/,
        /^https?:\/\/(www\.)?facebook\.com\/profile\.php\?id=([0-9]+).*$/
      ]
    )
  end

  def facebook_user_fields
    %w(
      link        name                first_name     id            last_name    picture              timezone
      albums      books               events         family        games        groups               likes
      movies      music               photos         tagged_places television   videos               feed
      about       age_range           bio            birthday      cover        currency             education
      email       favorite_athletes   favorite_teams gender        hometown     inspirational_people interested_in
      is_verified languages           locale         location      middle_name  name_format          political
      quotes      relationship_status religion       sports        updated_time verified             website
    )
  end

  def facebook_page_fields
    %w(
      id                  about            awards         bio              birthday             built                 can_checkin
      category            category_list    checkins       company_overview contact_address      context               country_page_likes
      cover               current_location description    display_subtext  emails               founded               general_info
      general_manager     genre            hometown       hours            is_community_page    is_permanently_closed is_published
      is_unclaimed        is_verified      keywords       last_used_time   leadgen_tos_accepted link                  location
      name                network          new_like_count parent_page      personal_info        phone                 press_contact
      talking_about_count username         voip_info      website          were_here_count      written_by            events
      insights            likes            locations      photos           picture
    )
  end

  def facebook_client
    Koala::Facebook::API.new CONFIG['facebook_auth_token']
  end

  def get_data_from_facebook
    data = {}
    id = self.get_facebook_id_from_url
    client = self.facebook_client
    # Try to parse as a user profile first
    begin
      data = client.get_object(id, { fields: self.facebook_user_fields }, { method: 'post' })
      data['subtype'] = 'user'
    # If it fails, try to parse as a page
    rescue
      data = client.get_object(id, { fields: self.facebook_page_fields }, { method: 'post' })
      data['subtype'] = 'page'
    end
    data['published_at'] = ''
    data
  end

  def normalize_facebook_url
    attempts = 0
    code = '301'
    
    while attempts < 5 && code == '301'
      attempts += 1
      uri = URI.parse(self.url)
      http = Net::HTTP.new(uri.host, uri.port)

      unless self.url.match(/^https/).nil?
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      code = response.code
    
      if code == '301'
        self.url = response.header['location']
      end
    end
  end

  def data_from_facebook_profile
    self.normalize_facebook_url
    self.data.merge! self.get_data_from_facebook
    self.data[:username] = self.get_facebook_username
    description = self.data['bio'] || self.data['about'] || ''
    self.data.merge!({ title: self.data['name'], description: description, picture: self.facebook_picture })
  end

  def facebook_picture
    data = self.data
    picture = ''
    if data['picture'] && data['picture']['data'] && data['picture']['data']['url']
      picture = data['picture']['data']['url']
    end
    picture
  end

  def get_facebook_username
    match = self.url.match(/^https?:\/\/(www\.)?facebook\.com\/([^\/\?]+)/)
    match = self.url.match(/^https?:\/\/([^\.]+\.)?facebook\.com\/people\/([^\/\?]+)/) if match.nil?
    username = match[2]
    if username === 'pages'
      username = self.url.match(/^https?:\/\/(www\.)?facebook\.com\/pages\/([^\/]+)\/([^\/\?]+).*/)[2]
    # elsif username === 'profile.php'
    #   username = self.data['name'].delete(' ')
    end
    username
  end

  def get_facebook_id_from_url
    IdsPlease.new(self.url).grab[:facebook].first.network_id.to_i
  end
end
