class MetricsWorker
  include Sidekiq::Worker

  def perform(url, key_id, count, facebook_id = nil)
    Metrics.get_metrics_from_facebook(url, key_id, count, facebook_id)
  end
end
