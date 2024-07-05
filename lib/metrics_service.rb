require 'prometheus/client'

class MetricsService
  class << self
    def custom_counter(name, description, labels: [])
      counter = Prometheus::Client::Counter.new(
        name, 
        docstring: description,
        labels: labels,
        preset_labels: { service: 'pender' }
        )
      prometheus_registry.register(counter)
    end

    def increment_counter(name, labels: [])
      counter = prometheus_registry.get(name)
      return if counter.nil?

      counter.increment(labels: labels)
    end

    def get_counter(counter, labels: [])
      counter.get(labels: labels)
    end

    private

    def prometheus_registry
      Prometheus::Client.registry
    end

  end
end
