module Pender
  class OpenTelemetryTestConfig
    class << self
      def configure!
        raise StandardError.new("[otel] Test config being used in non-test environment") unless Rails.env.test?

        # Supplement Open Telemetry config in initializer to capture spans in test
        # https://github.com/open-telemetry/opentelemetry-ruby-contrib/blob/main/.instrumentation_generator/templates/test/test_helper.rb
      
        # By default this discards spans. To enable recording for test purposes, 
        # set the following in the test setup block:
        # 
        # Pender::OpenTelemetryTestConfig.current_exporter.recording = true
        @exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new(recording: false)
        OpenTelemetry::SDK.configure do |c|
          c.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(@exporter))
      
          # Keep this list in sync with Pender::OpenTelemetryConfig, to make sure we track
          # any potential issues coming from instrumentation libraries
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
        @exporter
      end

      def current_exporter
        @exporter || configure!
      end
    end
  end
end
