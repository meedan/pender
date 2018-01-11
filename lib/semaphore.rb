class Semaphore
  def initialize(key)
    unless CONFIG.nil?
      @key = "semaphore:#{key}"
      @redis = Redis.new({ host: CONFIG[:redis_host], port: CONFIG[:redis_port], db: CONFIG[:redis_database] })
    end
  end

  def lock
    @redis.getset(@key, Time.now) unless CONFIG.nil?
  end

  def locked?
    CONFIG.nil? ? false : !@redis.get(@key).nil?
  end

  def unlock
    @redis.del(@key) unless CONFIG.nil?
  end
end
