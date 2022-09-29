require 'pender_open_telemetry_config'

Pender::OpenTelemetryConfig.new(
  PenderConfig.get('otel_exporter_otlp_endpoint'),
  PenderConfig.get('otel_exporter_otlp_headers'),
  ENV['PENDER_SKIP_HONEYCOMB']
).configure!(
  PenderConfig.get('otel_resource_attributes')
)
