class MetricsWorker
  include Sidekiq::Worker

  def perform(url, key_id, count)
    key = ApiKey.where(id: key_id).first
    Media.get_metrics_from_facebook(url, key_id, count + 1) if count < 10
  end
end

