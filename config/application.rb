require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Pender
  class Application < Rails::Application
    config.load_defaults 6.0

    config.generators do |g|
      g.javascripts false
      g.stylesheets false
      g.template_engine false
      g.helper false
      g.assets false
    end

    config.autoload_paths << Rails.root.join("lib")
    config.eager_load_paths << Rails.root.join("lib")

    cfg = YAML.load_file("#{Rails.root}/config/config.yml")[Rails.env]
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*',
          headers: [cfg['authorization_header'], 'Content-Type', 'Accept'],
          methods: [:get, :post, :delete, :options]
      end
    end

    config.action_dispatch.default_headers.merge!({
      'Access-Control-Allow-Credentials' => 'true',
      'Access-Control-Request-Method' => '*'
    })

    config.active_record.yaml_column_permitted_classes = [Symbol]
  end
end

# Workaround for https://github.com/rswag/rswag/issues/359
# Move to config/environments/test.rb after issue is fixed.
# Enable Rswag auto generation examples from responses
if Rails.env.test?
  RSpec.configure do |config|
    config.swagger_dry_run = false
  end
end
