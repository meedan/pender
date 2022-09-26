require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/all'

if PenderConfig.get('otel_exporter_otlp_endpoint') && PenderConfig.get('otel_exporter_otlp_headers')
  # Set OpenTelemetry automatic instrumentation config in environment
  # https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/sdk-environment-variables.md
  ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = PenderConfig.get('otel_exporter_otlp_endpoint')
  ENV['OTEL_EXPORTER_OTLP_HEADERS'] = PenderConfig.get('otel_exporter_otlp_headers')
  ENV['OTEL_RESOURCE_ATTRIBUTES'] = (PenderConfig.get('otel_resource_attributes') || {}).map{ |k, v| "#{k}=#{v}"}.join(',')
  
  # Below can be uncommented to see traces logged locally rather than reported remotely
  # ENV['OTEL_TRACES_EXPORTER'] = 'console'

  OpenTelemetry::SDK.configure do |c|
    c.service_name = PenderConfig.get('otel_service_name') || 'pender'
  
    c.use 'OpenTelemetry::Instrumentation::ActiveSupport'
    c.use 'OpenTelemetry::Instrumentation::Rack'
    c.use 'OpenTelemetry::Instrumentation::ActionPack'
    c.use 'OpenTelemetry::Instrumentation::ActiveJob'
    c.use 'OpenTelemetry::Instrumentation::ActiveRecord'
    c.use 'OpenTelemetry::Instrumentation::ActionView'
    c.use 'OpenTelemetry::Instrumentation::AwsSdk'
    c.use 'OpenTelemetry::Instrumentation::HTTP'
    c.use 'OpenTelemetry::Instrumentation::ConcurrentRuby'
    c.use 'OpenTelemetry::Instrumentation::Net::HTTP'
    c.use 'OpenTelemetry::Instrumentation::Rails'
    c.use 'OpenTelemetry::Instrumentation::Redis'
    c.use 'OpenTelemetry::Instrumentation::Sidekiq'
  end
end
