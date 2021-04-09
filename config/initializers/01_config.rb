file = File.join(Rails.root, 'config', 'config.yml')

begin
  CONFIG = (YAML.load_file(file)[Rails.env]).with_indifferent_access
rescue
  raise "Error when loading configuration file"
end
WebMock.allow_net_connect!
