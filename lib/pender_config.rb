class PenderConfig

  def self.current(config_key = nil)
    RequestStore.store[:config] ||= {}.with_indifferent_access
    RequestStore.store[:config][config_key] ||= PenderConfig.load(config_key) if config_key
  end

  def self.current=(config)
    RequestStore.store[:config] = config
  end

  def self.reload
    RequestStore.store[:config] = {}.with_indifferent_access
  end

  def self.load(config_key)
    api_key = ApiKey.current
    if api_key && api_key.settings.dig(:config, config_key)
      api_key.settings[:config][config_key]
    else
      value = ENV[config_key.to_s]
      value.nil? && CONFIG.has_key?(config_key) ? CONFIG[config_key] : value
    end
  end

  def self.get(config_key, default = nil, type = nil)
    config_value = PenderConfig.current(config_key)
    return default unless config_value
    value = config_value || default
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
