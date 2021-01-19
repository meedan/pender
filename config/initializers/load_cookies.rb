COOKIES_PATH = 'config/cookies.txt'

PenderConfig.set('cookies', {}) if PenderConfig.get('cookies').nil?
if File.file?(COOKIES_PATH)
  File.readlines(COOKIES_PATH).each do |line|
    data = line.split("\t")
    next if data[0].start_with?('#')
    CONFIG['cookies'][data[0]] ||= {}
    CONFIG['cookies'][data[0]][data[5]] = data[6].strip if data[6]
  end
end
