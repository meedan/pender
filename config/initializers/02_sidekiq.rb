require 'sidekiq'
# require 'sidekiq/scheduler'
file = File.join(Rails.root, 'config', 'sidekiq.yml')
# scheduler = YAML.load_file(File.join(Rails.root, 'config', 'scheduler.yml'))
if File.exist?(file)
  SIDEKIQ_CONFIG = YAML.load_file(file)

  redis_config = { url: "redis://#{SIDEKIQ_CONFIG[:redis_host]}:#{SIDEKIQ_CONFIG[:redis_port]}/#{SIDEKIQ_CONFIG[:redis_database]}", namespace: "sidekiq_pender_#{Rails.env}" }

  Sidekiq.configure_server do |config|
    config.redis = redis_config
    # config.on(:startup) do
    #   Sidekiq.schedule = scheduler
    #   Sidekiq::Scheduler.reload_schedule!
    # end
  end

  Sidekiq.configure_client do |config|
    config.redis = redis_config
  end
else
  SIDEKIQ_CONFIG = nil
  Sidekiq.configure_server do |config|
    # config.on(:startup) do
    #   Sidekiq.schedule = scheduler
    #   Sidekiq::Scheduler.reload_schedule!
    # end
  end
end
Sidekiq::Extensions.enable_delay!
