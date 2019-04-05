VERSION = 'v0.70.0'

if ENV['RAILS_ENV'] == 'development'
  path = File.absolute_path(__FILE__)
  begin
    response = `curl https://api.github.com/repos/meedan/pender/tags`
    parsed_response = JSON.parse response
    if parsed_response.is_a?(Array) && parsed_response.first.dig('name')
      latest_version = parsed_response.first.dig('name')
      if latest_version != VERSION
        VERSION.clear << latest_version
        `sed -i "1s/VERSION = '.*'/VERSION = '#{VERSION}'/" #{path}`
      end
    elsif parsed_response.is_a?(Hash) && parsed_response.dig('message')
      puts "Could not get latest version: `#{parsed_response.dig('message')}`"
    end
  rescue StandardError => e
    puts "Could not get latest version: `#{e.inspect}`"
  end
end
