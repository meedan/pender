require 'lograge'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Spring reloads application code, and therefore needs the application to have reloading enabled.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  # Whitelist docker access
  config.web_console.whitelisted_ips = '172.0.0.0/8'

  # Enable the logstasher logs for the current environment
  # config.logger = LogStashLogger.new(type: :udp, host: 'logstash', port: 5228)
  # config.logstash.uri = 'udp://logstash:5228'

  config.allow_concurrency = true

  config.lograge.enabled = true
  config.lograge.custom_options = lambda do |event|
    options = event.payload.slice(:request_id, :user_id)
    options[:params] = event.payload[:params].except("controller", "action")
    status = event.payload[:status].to_i
    options[:level] =
      if status < 300
        'INFO'
      elsif status < 400
        'WARN'
      else
        'ERROR'
      end
    options
  end
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.logger = ActiveSupport::Logger.new(STDOUT)

  config.log_level = :debug

  cfg = YAML.load_file("#{Rails.root}/config/config.yml")[Rails.env]
  if cfg['whitelisted_hosts']
    config.hosts.concat(cfg['whitelisted_hosts'].split(','))
  else
    puts '[WARNING] config.hosts not provided. Only requests from localhost are allowed. To change, update `whitelisted_hosts` in config.yml'
  end
end
