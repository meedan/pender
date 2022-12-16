class MetricsWorker
  include Sidekiq::Worker

  # approximately ~17hrs from start
  # https://github.com/mperham/sidekiq/wiki/Error-Handling#automatic-job-retry
  sidekiq_options retry: 13

  def perform(url, key_id, count, facebook_id = nil)
    Metrics.get_metrics_from_facebook(url, key_id, count, facebook_id)
  end
end
