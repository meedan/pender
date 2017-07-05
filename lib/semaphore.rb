class Semaphore
  def initialize(key)
    @key = "semaphore:#{key}"
    @redis = Redis.new({ host: SIDEKIQ_CONFIG[:redis_host], port: SIDEKIQ_CONFIG[:redis_port], db: SIDEKIQ_CONFIG[:redis_database] })
  end

  def lock
    @redis.getset(@key, Time.now)
  end

  def locked?
    !@redis.get(@key).nil?
  end

  def unlock
    @redis.del(@key)
  end
end
