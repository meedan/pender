module MediaCrowdtangleItem
  extend ActiveSupport::Concern

  def get_crowdtangle_id(resource)
    if resource == :instagram
      media_info = self.data.dig('raw', 'graphql', 'shortcode_media')
      media_info.nil? ? nil : "#{media_info['id']}_#{media_info['owner']['id']}"
    else
      self.data.dig('uuid')
    end
  end

  def get_crowdtangle_data(resource)
    id = self.get_crowdtangle_id(resource)
    self.data['raw']['crowdtangle'] = { error: { message: 'Unknown ID', code: LapisConstants::ErrorCodes::const_get('UNKNOWN') }} and return if id.blank?
    crowdtangle_data = Media.crowdtangle_request(resource, id).with_indifferent_access
    unless crowdtangle_data && crowdtangle_data['result']
      self.data['raw']['crowdtangle'] = { error: { message: "Cannot get data from Crowdtangle. #{crowdtangle_data['notes']}", code: LapisConstants::ErrorCodes::const_get('UNKNOWN') }} and return
    end
    self.data['raw']['crowdtangle'] = crowdtangle_data['result']
    post_info = crowdtangle_data['result']['posts'].first
    self.send("get_crowdtangle_#{resource}_result", post_info)
  end

  def get_crowdtangle_instagram_result(post_info)
    self.data[:author_name] = post_info.dig('account', 'name')
    self.data[:username] = '@' + post_info.dig('account', 'handle')
    self.data[:author_url] = post_info.dig('account', 'url')
    self.data[:description] = self.data[:title] = post_info.dig('description')
    self.data[:picture] = post_info.dig('media').first['url'] if post_info.dig('media')
    self.data[:published_at] = post_info.dig('date')
  end

  def get_crowdtangle_facebook_result(post_info)
    self.url = post_info.dig('postUrl') if post_info.dig('postUrl') && post_info.dig('postUrl') != self.url
    self.data[:author_name] = post_info.dig('account', 'name')
    self.data[:username] = post_info.dig('account', 'handle')
    self.data[:author_picture] = post_info.dig('account', 'profileImage')
    self.data[:author_url] = post_info.dig('account', 'url')
    self.data[:description] = self.data[:text] = post_info.dig('message')
    self.data[:external_id] = post_info.dig('platformId')
    self.data[:object_id] = post_info.dig('platformId')
    self.data[:picture] = post_info['media'].first['full'] if post_info.dig('media')
    self.data[:published_at] = post_info.dig('date')
  end

  Media.class_eval do
    def self.crowdtangle_request(resource, id)
      uri = URI.parse("https://api.crowdtangle.com/post/#{id}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      headers = { 'X-API-Token' => PenderConfig.get("crowdtangle_#{resource}_token") }
      request = Net::HTTP::Get.new(uri.request_uri, headers)

      response = http.request(request)
      return {} unless !response.nil? && response.code == '200' && !response.body.blank?
      begin
        JSON.parse(response.body)
      rescue JSON::ParserError => error
        PenderAirbrake.notify(StandardError.new('Could not parse `crowdtangle` data as JSON'), crowdtangle_url: uri, error_message: error.message, response_body: response.body )
        Rails.logger.warn level: 'WARN', message: '[Parser] Could not get `crowdtangle` data', crowdtangle_url: uri, error_class: error.class, response_code: response.code, response_message: response.message
        {}
      end
    end
  end
end
