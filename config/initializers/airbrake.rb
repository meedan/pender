require 'pender_config'

unless PenderConfig.get('airbrake_host').blank?
  Airbrake.configure do |config|
    config.project_key = PenderConfig.get('airbrake_project_key')
    config.project_id = 1
    config.host = "https://#{PenderConfig.get('airbrake_host')}:#{PenderConfig.get('airbrake_port')}"
    config.ignore_environments = %w(development test)
    config.environment = PenderConfig.get('airbrake_environment')
    config.performance_stats = false
  end

  DEFAULT_MAX_SIDEKIQ_RETRIES = 25
  Airbrake.add_filter do |notice|
    # Ideally we'd handle this filter as part of sidekiq_retries_exhausted in future. For now we magic number it
    if notice[:errors].any? { |error| error[:type] == 'Pender::Exception::RetryLater' } && notice[:params][:job] && notice[:params][:job].dig('retry_count').to_i < (SIDEKIQ_CONFIG[:max_retries] || DEFAULT_MAX_SIDEKIQ_RETRIES)
      notice.ignore!
    end
  end
end
