require 'pender_open_telemetry_config'
require 'pender_open_telemetry_test_config'

# Lines immediately below set any environment config that should 
# be applied to all environments
ENV['OTEL_LOG_LEVEL'] = PenderConfig.get('otel_log_level')

unless Rails.env.test?
  Pender::OpenTelemetryConfig.new(
    PenderConfig.get('otel_exporter_otlp_endpoint'),
    PenderConfig.get('otel_exporter_otlp_headers'),
    ENV['PENDER_SKIP_HONEYCOMB']
  ).configure!(
    PenderConfig.get('otel_resource_attributes'),
    sampling_config: {
      sampler: PenderConfig.get('otel_traces_sampler'),
      rate: PenderConfig.get('otel_custom_sampling_rate')
    }
  )
else
  Pender::OpenTelemetryTestConfig.configure!
end
