class Semaphore
  def initialize(key)
    redis_config = PenderConfig.get('redis', {})
    unless redis_config.empty?
      @key = "semaphore:#{key}"
      @redis = Redis.new({ host: redis_config['host'], port: redis_config['port'], db: redis_config['database'] })
    end
  end

  def lock
    # PenderConfig('timeout') sets the max time for a page to be parsed,
    # so the lock duration needs to be at least higher than its value
    timeout = (PenderConfig.get('timeout') || 20) + 4
    @redis.set(@key, Time.now, ex: timeout.round) if @redis
  end

  def locked?
    @redis ? !@redis.get(@key).nil? : false
  end

  def unlock
    @redis.del(@key) if @redis
  end
end
