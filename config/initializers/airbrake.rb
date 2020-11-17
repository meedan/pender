unless PenderConfig.get('airbrake_host').blank?
  Airbrake.configure do |config|
    config.project_key = PenderConfig.get('airbrake_project_key')
    config.project_id = 1
    config.host = "https://#{PenderConfig.get('airbrake_host')}:#{PenderConfig.get('airbrake_port')}"
    config.ignore_environments = %w(development test)
    config.environment = PenderConfig.get('airbrake_environment')
  end

  Airbrake.add_filter do |notice|
    if notice[:errors].any? { |error| error[:type] == 'Pender::RetryLater' } && notice[:params][:job] && notice[:params][:job].dig('retry_count').to_i < SIDEKIQ_CONFIG[:max_retries]
      notice.ignore!
    end
  end
end
