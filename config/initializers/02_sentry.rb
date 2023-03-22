require 'pender_config'

Sentry.init do |config|
  config.dsn = PenderConfig.get('sentry_dsn')
  config.environment = PenderConfig.get('sentry_environment')

  # Turns off trace reporting entirely by default, since we are currently using Honeycomb.
  # Can be modified via config, with a sentry_traces_sample_rate of 0 < x < 1
  config.traces_sample_rate = (PenderConfig.get('sentry_traces_sample_rate') || 0).to_f

  # Any exceptions we want to prevent sending to Sentry
  config.excluded_exceptions += ['Pender::Exception::RetryLater']
end
