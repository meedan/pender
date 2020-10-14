class MetricsWorker
  include Sidekiq::Worker

  def perform(url, key_id, count)
    Media.get_metrics_from_facebook(url, key_id, count) if count < 10
  end
end

