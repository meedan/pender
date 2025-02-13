require 'sidekiq'

file = File.join(Rails.root, 'config', 'sidekiq.yml')

if File.exist?(file)
  SIDEKIQ_CONFIG = YAML.load_file(file)

  redis_config = { url: "redis://#{SIDEKIQ_CONFIG[:redis_host]}:#{SIDEKIQ_CONFIG[:redis_port]}/#{SIDEKIQ_CONFIG[:redis_database]}" }

  Sidekiq.configure_server do |config|
    config.redis = redis_config

    config.death_handlers << ->(job, original_exception) do
      case original_exception
      when Pender::Exception::RetryLater
        if original_exception.message.include?("Too Many Requests")
          rate_limit_exception = Pender::Exception::RateLimitExceeded.new(original_exception)
          PenderSentry.notify(rate_limit_exception, { job: job, original_exception: original_exception.cause.inspect })
        else
          limit_hit_exception = Pender::Exception::RetryLimitHit.new(original_exception)
          PenderSentry.notify(limit_hit_exception, { job: job, original_exception: original_exception.cause.inspect })
        end
      when Pender::Exception::RetryLimitHit
        Rails.logger.warn level: 'WARN', message: "Archiver rate limited: Too many requests. Job: #{job}"
        PenderSentry.notify(original_exception, { job: job, rate_limited: true })
      else
        PenderSentry.notify(original_exception, { job: job })
      end
    end
  end
  
  Sidekiq.configure_client do |config|
    config.redis = redis_config
    config.logger.level = ::Logger::WARN
  end
else
  SIDEKIQ_CONFIG = nil
end
