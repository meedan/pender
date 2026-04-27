# A convenience wrapper class for Open Telemetry
class TracingService
  class << self
    def add_attributes_to_current_span(attributes)
      current_span = OpenTelemetry::Trace.current_span
      add_attributes(current_span, attributes)
    end

    # Set error on span in Otel without a corresponding exception
    def set_error_status(error_message, attributes: {})
      current_span = OpenTelemetry::Trace.current_span
      current_span.status = OpenTelemetry::Trace::Status.error(error_message)
      add_attributes(current_span, attributes)
    end

    # Set error on span in Otel with a corresponding exception
    def record_exception(e = nil, error_message = nil, attributes: {})
      current_span = OpenTelemetry::Trace.current_span
      current_span.status = OpenTelemetry::Trace::Status.error(error_message || e.message)
      current_span.record_exception(e, attributes: format_attributes(attributes))
    end

    private

    def format_attributes(attributes)
      attributes.compact
    end

    def add_attributes(current_span, attributes)
      return if attributes.empty?
      current_span.add_attributes(format_attributes(attributes))
    end
  end
end
