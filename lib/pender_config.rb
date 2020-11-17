class PenderConfig

  def self.current
    RequestStore.store[:config] ||= PenderConfig.load
  end

  def self.current=(config)
    RequestStore.store[:config] = config
  end

  def self.reload
    PenderConfig.current = PenderConfig.load
  end

  def self.load
    api_key = ApiKey.current
    api_key && api_key.settings[:config] ? CONFIG.merge(api_key.settings[:config]) : CONFIG
  end

  def self.get(config_key, default = nil, type = nil)
    config = PenderConfig.current
    return default if !config.has_key?(config_key)
    value = config[config_key] || default
    type == :json ? get_json_config(value, default) : value
  end

  def self.get_json_config(value, default)
    begin
      JSON.parse(value)
    rescue JSON::ParserError
      default
    end
  end
end
