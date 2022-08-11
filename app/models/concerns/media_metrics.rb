module MediaMetrics
  extend ActiveSupport::Concern

  module ClassMethods
    def notify_webhook_and_update_metrics_cache(url, name, value, key_id)
      return if value.nil?
      settings = Media.api_key_settings(key_id)
      data = { 'metrics' => { name => value } }
      Media.notify_webhook('metrics', url, data, settings)
      Media.update_cache(url, data)
    end
  end
end
