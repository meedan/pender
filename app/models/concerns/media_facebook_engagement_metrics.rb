module MediaFacebookEngagementMetrics
  extend ActiveSupport::Concern

  included do
    Media.declare_metrics('facebook')
  end

  def get_metrics_from_facebook
    self.class.get_metrics_from_facebook_in_background(self.url, ApiKey.current&.id)
  end

  module ClassMethods
    def get_metrics_from_facebook_in_background(url, key_id)
      self.delay_for(1.second).get_metrics_from_facebook(url, key_id, 1)
    end

    def request_metrics_from_facebook(url)
      facebook = PenderConfig.get('facebook')
      api = "https://graph.facebook.com/oauth/access_token?client_id=#{facebook.dig('app_id')}&client_secret=#{facebook.dig('app_secret')}&grant_type=client_credentials"
      response = Net::HTTP.get_response(URI(api))
      token = JSON.parse(response.body)['access_token']
      api = "https://graph.facebook.com/?id=#{url}&fields=engagement&access_token=#{token}"
      response = Net::HTTP.get_response(URI(URI.encode(api)))
      JSON.parse(response.body)['engagement']
    end

    def get_metrics_from_facebook(url, key_id, count)
      value = begin
                self.request_metrics_from_facebook(url)
              rescue StandardError => e
                Airbrake.notify(e, url: url) if Airbrake.configured?
                {}
              end
      Media.notify_webhook_and_update_metrics_cache(url, 'facebook', value, key_id)
      self.delay_for(24.hours).get_metrics_from_facebook(url, key_id, count + 1) if count < 10
    end
  end
end
