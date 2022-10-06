require 'pender_open_telemetry_config'
require 'pender_open_telemetry_test_config'

unless Rails.env.test?
  Pender::OpenTelemetryConfig.new(
    PenderConfig.get('otel_exporter_otlp_endpoint'),
    PenderConfig.get('otel_exporter_otlp_headers'),
    ENV['PENDER_SKIP_HONEYCOMB']
  ).configure!(
    PenderConfig.get('otel_resource_attributes')
  )
else
  Pender::OpenTelemetryTestConfig.configure!
end
