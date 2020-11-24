class Semaphore
  def initialize(key)
    host = PenderConfig.get('redis_host')
    port = PenderConfig.get('redis_port')
    db = PenderConfig.get('redis_database')
    if host && port && db
      @key = "semaphore:#{key}"
      @redis = Redis.new({ host: host, port: port, db: db })
    end
  end

  def lock
    # PenderConfig('timeout') sets the max time for a page to be parsed,
    # so the lock duration needs to be at least higher than its value
    timeout = (PenderConfig.get('timeout').to_i || 20) + 4
    @redis.set(@key, Time.now, ex: timeout.round) if @redis
  end

  def locked?
    @redis ? !@redis.get(@key).nil? : false
  end

  def unlock
    @redis.del(@key) if @redis
  end
end
