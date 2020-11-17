namespace :test do
  task :coverage do
    require 'simplecov'
    require 'simplecov-console'
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::Console,
    ])

    SimpleCov.use_merging true

    SimpleCov.start 'rails' do
      add_filter do |file|
        !file.filename.match(/\/lib\/pender_redis\.rb$/).nil?
      end
      coverage_dir 'coverage'
    end
    Rake::Task['test'].execute
    Rake::Task['spec'].execute
  end
end
