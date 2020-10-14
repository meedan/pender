class MetricsWorker
  include Sidekiq::Worker

  sidekiq_retries_exhausted { |msg, e| retries_exhausted_callback(msg, e) }

  def self.retries_exhausted_callback(msg, e)
    PenderAirbrake.notify("Facebook metrics: #{e.message}", msg)
  end

  def perform(url, key_id, count)
    key = ApiKey.where(id: key_id).first
    Media.get_metrics_from_facebook(url, key_id, count + 1) if count < 10
  end
end

