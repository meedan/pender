CONFIG = (YAML.load_file("#{Rails.root}/config/config.yml")[Rails.env]).with_indifferent_access
WebMock.allow_net_connect!
