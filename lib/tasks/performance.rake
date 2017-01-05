namespace :test do
  task :performance do
    output = File.join(Rails.root, 'tmp', 'performance.csv')
    results = File.open(output, 'w+')
    results.puts 'Operation;Time (ms)'
    results.close
    
    Dir["#{File.join(Rails.root, 'test', 'performance')}/**/*.rb"].each do |file|
      next if file =~ /base_performance\.rb$/
      puts
      puts `ruby #{file} 2>&1 | grep 'Test#' -A 3 | grep -v Base`
    end
    
    puts
    puts "Check the results at #{output}"
  end
end
