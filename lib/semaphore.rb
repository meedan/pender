class Semaphore
  def initialize(key)
    unless SIDEKIQ_CONFIG.nil?
      @key = "semaphore:#{key}"
      @redis = Redis.new({ host: SIDEKIQ_CONFIG[:redis_host], port: SIDEKIQ_CONFIG[:redis_port], db: SIDEKIQ_CONFIG[:redis_database] })
    end
  end

  def lock
    @redis.getset(@key, Time.now) unless SIDEKIQ_CONFIG.nil?
  end

  def locked?
    SIDEKIQ_CONFIG.nil? ? false : !@redis.get(@key).nil?
  end

  def unlock
    @redis.del(@key) unless SIDEKIQ_CONFIG.nil?
  end
end
