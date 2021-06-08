class AddApplicationSettingsToApiKeys < ActiveRecord::Migration[4.2]
  def change
    add_column :api_keys, :application_settings, :text
  end
end
