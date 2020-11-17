require 'simplecov-console'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::Console,
])

SimpleCov.use_merging true

SimpleCov.start 'rails' do
  nocov_token 'nocov'
  merge_timeout 3600
  command_name "Tests #{rand(100000)}"
  add_filter do |file|
    !file.filename.match(/\/lib\/pender_redis\.rb$/).nil?
  end
  coverage_dir 'coverage'
end
