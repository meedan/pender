class PenderRedis
  def initialize
    @redis = SIDEKIQ_CONFIG.nil? ? Redis.new : Redis.new({ host: SIDEKIQ_CONFIG[:redis_host], port: SIDEKIQ_CONFIG[:redis_port], db: SIDEKIQ_CONFIG[:redis_database] })
  end

  def redis
    @redis
  end
end
