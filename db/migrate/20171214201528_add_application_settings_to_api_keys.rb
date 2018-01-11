class AddApplicationSettingsToApiKeys < ActiveRecord::Migration
  def change
    add_column :api_keys, :application_settings, :text
  end
end
