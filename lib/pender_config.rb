class PenderConfig

  def self.current
    RequestStore.store[:config] ||= PenderConfig.load
  end

  def self.current=(config)
    RequestStore.store[:config] = config
  end

  def self.load
    api_key = ApiKey.current
    api_key && api_key.settings[:config] ? CONFIG.merge(api_key.settings[:config]) : CONFIG
  end

  def self.get(config_key, default = nil)
    config = PenderConfig.current
    return default if !config.has_key?(config_key)
    config[config_key]
  end
end
