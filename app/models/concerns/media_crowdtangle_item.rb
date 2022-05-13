module MediaCrowdtangleItem
  extend ActiveSupport::Concern

  def get_crowdtangle_id(resource)
    self.data.dig('uuid')
  end

  def get_crowdtangle_data(resource)
    id = self.get_crowdtangle_id(resource)
    puts "ID: #{id}"
    self.data['raw']['crowdtangle'] = { error: { message: 'Unknown ID', code: LapisConstants::ErrorCodes::const_get('UNKNOWN') }} and return if id.blank?
    crowdtangle_data = Media.crowdtangle_request(resource, id).with_indifferent_access
    result = crowdtangle_data.dig('result')
    post_info = (crowdtangle_data.dig('result', 'posts') || []).first
    unless post_info&.dig('platformId') == id
      self.data['raw']['crowdtangle'] = { error: { message: "Cannot get data from Crowdtangle. #{crowdtangle_data['notes']}", code: LapisConstants::ErrorCodes::const_get('UNKNOWN') }} and return
    end
    self.data['raw']['crowdtangle'] = result
    self.send("get_crowdtangle_#{resource}_result", post_info)
  end

  def get_crowdtangle_facebook_result(post_info)
    self.url = post_info.dig('postUrl') if post_info.dig('postUrl') && post_info.dig('postUrl') != self.url
    self.data[:author_name] = post_info.dig('account', 'name')
    self.data[:username] = post_info.dig('account', 'handle')
    self.data[:author_picture] = post_info.dig('account', 'profileImage')
    self.data[:author_url] = post_info.dig('account', 'url')
    self.data[:title] = self.data[:description] = self.data[:text] = post_info.dig('message')
    self.data[:external_id] = post_info.dig('platformId')
    self.data[:object_id] = post_info.dig('platformId')
    self.data[:picture] = (post_info.dig('media').select { |m| m['type'] == 'photo'}.first || {}).dig('full') if post_info.dig('media')
    self.data[:published_at] = post_info.dig('date')
  end

  def has_valid_crowdtangle_data?
    !self.data.dig('raw', 'crowdtangle').blank? && self.data.dig('raw', 'crowdtangle', 'error').nil?
  end

  Media.class_eval do
    def self.crowdtangle_request(resource, id)
      # Cache to avoid hitting rate limits and to avoid making several requests to Crowdtangle during the same request life cycle
      Rails.cache.fetch("crowdtangle:request:#{resource}:#{id}", expires_in: 1.minute) do
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
end
