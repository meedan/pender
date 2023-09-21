require 'sidekiq'

file = File.join(Rails.root, 'config', 'sidekiq.yml')

if File.exist?(file)
  SIDEKIQ_CONFIG = YAML.load_file(file)

  redis_config = { url: "redis://#{SIDEKIQ_CONFIG[:redis_host]}:#{SIDEKIQ_CONFIG[:redis_port]}/#{SIDEKIQ_CONFIG[:redis_database]}" }

  Sidekiq.configure_server do |config|
    config.redis = redis_config

    config.death_handlers << ->(job, ex) do
      if ex.is_a?(Pender::Exception::RetryLater)
        ex = Pender::Exception::RetryLimitHit.new(ex)
      end
      PenderSentry.notify(ex, {job: job})
    end
  end

  Sidekiq.configure_client do |config|
    config.redis = redis_config
  end
else
  SIDEKIQ_CONFIG = nil
end
Sidekiq::Extensions.enable_delay!
