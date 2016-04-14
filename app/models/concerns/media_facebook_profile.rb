module MediaFacebookProfile
  extend ActiveSupport::Concern

  #FIXME: Should work with pages as well
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
      link
      name
      first_name
      id
      last_name
      picture
      timezone
      albums
      books
      events
      family
      games
      groups
      likes
      movies
      music
      photos
      tagged_places
      television
      videos
      feed
      about
      age_range
      bio
      birthday
      cover
      currency
      education
      email
      favorite_athletes
      favorite_teams
      gender
      hometown
      inspirational_people
      interested_in
      is_verified
      languages
      locale
      location
      middle_name
      name_format
      political
      quotes
      relationship_status
      religion
      sports
      updated_time
      verified
      website
    )
  end

  def facebook_page_fields
    %w(
      id
      about
      artists_we_like
      awards
      best_page
      bio
      birthday
      built
      business
      can_checkin
      category
      category_list
      checkins
      company_overview
      contact_address
      context
      country_page_likes
      cover
      current_location
      description
      display_subtext
      emails
      features
      founded
      general_info
      general_manager
      genre
      hometown
      hours
      is_community_page
      is_permanently_closed
      is_published
      is_unclaimed
      is_verified
      keywords
      last_used_time
      leadgen_tos_accepted
      link
      location
      name
      network
      new_like_count
      parent_page
      personal_info
      personal_interests
      phone
      place_type
      press_contact
      talking_about_count
      username
      voip_info
      website
      were_here_count
      written_by
      albums
      events
      insights
      likes
      locations
      milestones
      photos
      picture
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
      data = client.get_object(id, fields: self.facebook_user_fields)
      data['subtype'] = 'user'
    # If it fails, try to parse as a page
    rescue
      data = client.get_object(id, { fields: self.facebook_page_fields }, { method: 'post' })
      data['subtype'] = 'page'
    end
    data
  end

  def data_from_facebook_profile
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
    username = self.url.match(/^https?:\/\/(www\.)?facebook\.com\/([^\/\?]+)/)[2]
    if username === 'pages'
      username = self.url.match(/^https?:\/\/(www\.)?facebook\.com\/pages\/([^\/]+)\/([^\/\?]+).*/)[2]
    elsif username === 'profile.php'
      username = self.data['name'].gsub(' ', '')
    end
    username
  end

  def get_facebook_id_from_url
    IdsPlease.new(self.url).grab[:facebook].first.network_id.to_i
  end
end
