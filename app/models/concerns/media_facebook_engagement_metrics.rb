require 'pender_exceptions'

module MediaFacebookEngagementMetrics
  extend ActiveSupport::Concern

  included do
    Media.declare_metrics('facebook')
  end

  def get_metrics_from_facebook
    facebook_id = self.data['uuid'] if is_a_facebook_post?
    self.class.get_metrics_from_facebook(self.original_url, ApiKey.current&.id, 0, facebook_id)
  end

  def is_a_facebook_post?
    self.data && self.data['provider'] == 'facebook' && self.data['type'] == 'item'
  end

  module ClassMethods
    def request_metrics_from_facebook(url)
      engagement = nil
      PenderConfig.get('facebook_app', '').split(';').each do |fb_app|
        app_id, app_secret = fb_app.split(':')
        @locker = Semaphore.new(app_id)
        next if @locker.locked?
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

    def get_metrics_from_facebook(url, key_id, count = 0, facebook_id = nil)
      ApiKey.current = ApiKey.find_by(id: key_id)
      begin
        value = facebook_id ? self.crowdtangle_metrics(facebook_id) : self.request_metrics_from_facebook(url)
        MetricsWorker.perform_in(24.hours, url, key_id, count + 1, facebook_id) if count < 10
      rescue Pender::RetryLater
        raise Pender::RetryLater, 'Metrics request failed'
      rescue StandardError => e
        value = {}
        PenderAirbrake.notify("Facebook metrics: #{e.message}", url: url, key_id: ApiKey.current&.id)
      end
      Media.notify_webhook_and_update_metrics_cache(url, 'facebook', value, key_id)
    end

    def verify_facebook_metrics_response(url, response)
      return true if response.code.to_i == 200
      error = JSON.parse(response.body)['error']
      unless fb_metrics_error(:permanent, url, error)
        PenderAirbrake.notify("Facebook metrics: #{error['message']}", url: url, key_id: ApiKey.current&.id, error_code: error['code'], error_class: error['type'])
        @locker.lock(3600) if error['code'].to_i == 4
        raise Pender::RetryLater, 'Metrics request failed' if fb_metrics_error(:retryable, url, error)
      end
    end

    def fb_metrics_error(type, url, response_error)
      errors = {
        permanent: {
          10 => 'Requires Facebook page permissions',
          100 => 'Unsupported get request. Facebook object ID does not support this operation',
          803 => 'The Facebook object ID is not correct or invalid'
        },
        retryable: {
          1 => 'Error validating client secret.',
          4 => 'Application request limit reached.',
          101 => 'Missing client_id parameter.'
        }
      }
      error = errors[type].dig(response_error['code'].to_i)
      return unless error
      Rails.logger.warn level: 'WARN', message: "[Parser] Facebook metrics error: #{error}", url: url, key_id: ApiKey.current&.id, error: response_error
      true
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
  end
end
