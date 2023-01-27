namespace :lapis do
  task :error_codes do
    Lapis::ErrorCodes::ALL.each do |name|
      puts name + ': ' + Lapis::ErrorCodes.const_get(name).to_s
    end
  end
end
