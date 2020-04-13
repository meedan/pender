class Semaphore
  def initialize(key)
    unless CONFIG.nil?
      @key = "semaphore:#{key}"
      @redis = Redis.new({ host: CONFIG['redis_host'], port: CONFIG['redis_port'], db: CONFIG['redis_database'] })
    end
  end

  def lock
    # CONFIG['timeout'] sets the max time for a page to be parsed,
    # so the lock duration needs to be at least higher than its value
    timeout = (CONFIG['timeout'] || 20) + 4
    @redis.set(@key, Time.now, ex: timeout.round) unless CONFIG.nil?
  end

  def locked?
    CONFIG.nil? ? false : !@redis.get(@key).nil?
  end

  def unlock
    @redis.del(@key) unless CONFIG.nil?
  end
end
