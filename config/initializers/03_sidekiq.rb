require 'sidekiq'

file = File.join(Rails.root, 'config', 'sidekiq.yml')

if File.exist?(file)
  SIDEKIQ_CONFIG = YAML.load_file(file)

  redis_config = { url: "redis://#{SIDEKIQ_CONFIG[:redis_host]}:#{SIDEKIQ_CONFIG[:redis_port]}/#{SIDEKIQ_CONFIG[:redis_database]}" }

  Sidekiq.configure_server do |config|
    config.redis = redis_config

    config.death_handlers << ->(job, original_exception) do
      if original_exception.is_a?(Pender::Exception::RetryLater)
        limit_hit_exception = Pender::Exception::RetryLimitHit.new(original_exception)
      end
      PenderSentry.notify(limit_hit_exception, {job: job, original_exception: original_exception.cause.inspect})
    end
  end

  Sidekiq.configure_client do |config|
    config.redis = redis_config
  end
else
  SIDEKIQ_CONFIG = nil
end
Sidekiq::Extensions.enable_delay!
