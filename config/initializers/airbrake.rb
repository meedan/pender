unless CONFIG['airbrake']['host'].blank?
  Airbrake.configure do |config|
    config.project_key = CONFIG['airbrake']['project_key']
    config.project_id = 1
    config.host = "https://#{CONFIG['airbrake']['host']}:#{CONFIG['airbrake']['port']}"
    config.ignore_environments = %w(development test)
    config.environment = CONFIG['airbrake']['environment']
  end

  Airbrake.add_filter do |notice|
    if notice[:errors].any? { |error| error[:type] == 'Pender::RetryLater' } && notice[:params][:job] && notice[:params][:job].dig('retry_count').to_i < SIDEKIQ_CONFIG[:max_retries]
      notice.ignore!
    end
  end
end
