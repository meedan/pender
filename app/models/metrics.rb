require 'pender_exceptions'

module Metrics
  class << self
    RETRYABLE_FACEBOOK_ERROR_CODES = [
      1, # Error validating client secret
      101, # Missing client_id parameter
    ]
    FACEBOOK_RATE_LIMIT_CODES = [
      4, # Application request limit reached
      613, # Calls to graph_url_engagement_count have exceeded the rate of 10 calls per 3600 seconds
    ]

    def get_metrics_from_facebook_in_background(data, original_url, key_id)
      facebook_id = data['uuid'] if is_a_facebook_post?(data)
      # Delaying a bit to prevent race condition where initial request that creates
      # record on Check API beats our metrics reporting
      MetricsWorker.perform_in(10.seconds, original_url, key_id, 0, facebook_id)
    end

    def get_metrics_from_facebook(url, key_id, count = 0, facebook_id = nil)
      Rails.logger.info level: 'INFO', message: "Requesting metrics from Facebook", url: url, key_id: ApiKey.current&.id, count: count, facebook_id: facebook_id
      ApiKey.current = ApiKey.find_by(id: key_id)
      begin
        value = facebook_id ? crowdtangle_metrics(facebook_id) : request_metrics_from_facebook(url)
        MetricsWorker.perform_in(24.hours, url, key_id, count + 1, facebook_id) if count < 10
      rescue Pender::RetryLater
        raise Pender::RetryLater, 'Metrics request failed'
      rescue StandardError => e
        value = {}
        Rails.logger.warn level: 'WARN', message: "Metrics request failed: #{e.message}", url: url, key_id: ApiKey.current&.id
        PenderAirbrake.notify("Facebook metrics: #{e.message}", url: url, key_id: ApiKey.current&.id)
      end
      notify_webhook_and_update_metrics_cache(url, 'facebook', value, key_id)
      value
    end

    private

    def is_a_facebook_post?(data)
      return false unless data.present?
      data['provider'] == 'facebook' && data['type'] == 'item'
    end

    def crowdtangle_metrics(id)
      crowdtangle_data = Media.crowdtangle_request('facebook', id)
      metrics = { comment_count: 0, reaction_count: 0, share_count: 0, comment_plugin_count: 0 }
      return metrics unless crowdtangle_data && crowdtangle_data['result'] && crowdtangle_data['result']['posts']
      post_info = crowdtangle_data['result']['posts'].first
      stats = post_info['statistics']['actual']
      reaction_count = 0
      ["likeCount", "loveCount", "wowCount", "hahaCount", "sadCount", "angryCount", "thankfulCount", "careCount"].each do |r|
        reaction_count += stats[r]
      end
      metrics[:comment_count] = stats['commentCount']
      metrics[:reaction_count] = reaction_count
      metrics[:share_count] = stats['shareCount']
      metrics
    end

    def request_metrics_from_facebook(url)
      engagement = {}
      PenderConfig.get('facebook_app', '').split(';').each do |fb_app|
        app_id, app_secret = fb_app.split(':')
        @locker = Semaphore.new(app_id)
        if @locker.locked?
          Rails.logger.warn level: 'WARN', message: "Skipping metrics request, app_id locked: #{app_id}", url: url, key_id: ApiKey.current&.id
          next
        end
        api = "https://graph.facebook.com/oauth/access_token?client_id=#{app_id}&client_secret=#{app_secret}&grant_type=client_credentials"
        response = Net::HTTP.get_response(URI(api))
        next unless verify_facebook_metrics_response(url, response)
        token = JSON.parse(response.body)['access_token']
        api = "https://graph.facebook.com/?id=#{url}&fields=engagement&access_token=#{token}"
        response = Net::HTTP.get_response(URI(URI.encode(api)))
        if verify_facebook_metrics_response(url, response)
          engagement = JSON.parse(response.body)['engagement']
          break
        end
      end
      engagement
    end

    def verify_facebook_metrics_response(url, response)
      return true if response.code.to_i == 200

      error = JSON.parse(response.body)['error']
      is_retryable = (RETRYABLE_FACEBOOK_ERROR_CODES + FACEBOOK_RATE_LIMIT_CODES).include?(error['code'].to_i)

      Rails.logger.warn level: 'WARN', message: "Facebook metrics error: #{error['code']} - #{error['message']}", url: url, key_id: ApiKey.current&.id, error: error, retryable: is_retryable
      TracingService.set_error_status(
        "Facebook metrics error",
        attributes: {
          'app.api_key' => ApiKey.current&.id,
          'facebook.metrics.error.code' => error['code'],
          'facebook.metrics.error.message' => error['message'],
          'facebook.metrics.url' => url,
          'facebook.metrics.retryable' => is_retryable
        }
      )
      if is_retryable
        @locker.lock(3600) if FACEBOOK_RATE_LIMIT_CODES.include?(error['code'].to_i)
        raise Pender::RetryLater, 'Metrics request failed'
      else
        PenderAirbrake.notify("Facebook metrics error: #{error['code']}", url: url, key_id: ApiKey.current&.id, error: error, retryable: is_retryable)
      end
    end

    def notify_webhook_and_update_metrics_cache(url, name, value, key_id)
      return if value.nil?
      settings = Media.api_key_settings(key_id)
      data = { 'metrics' => { name => value } }
      Media.update_cache(url, data)
      Media.notify_webhook('metrics', url, data, settings)
    end
  end
end
