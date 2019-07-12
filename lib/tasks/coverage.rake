namespace :test do
  task :coverage do
    require 'simplecov'
    require 'simplecov-console'
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::Console,
    ])
    SimpleCov.start 'rails' do
      add_filter do |file|
        !file.filename.match(/\/app\/controllers\/concerns\/[^\/]+_doc\.rb$/).nil? ||
        !file.filename.match(/\/app\/workers\/.*screenshot_worker\.rb$/).nil? ||
        !file.filename.match(/\/lib\/pender_redis\.rb$/).nil?
      end
      coverage_dir 'coverage'
    end
    Rake::Task['test'].execute
  end
end
