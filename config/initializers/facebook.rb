# Login on Facebook and store the cookie
COOKIES_PATH = CONFIG['facebook_cookies_filepath'] || '/tmp/fbcookies'

unless File.exists?(COOKIES_PATH)
  username = CONFIG['facebook_user'].to_s.gsub('+', '%2B')
  password = CONFIG['facebook_password']
  wget = "wget 'https://www.facebook.com/login.php?login_attempt=1' --post-data 'email=#{username}&pass=#{password}' --no-check-certificate --keep-session-cookies --save-cookies=#{COOKIES_PATH} --load-cookies=#{COOKIES_PATH} -U 'Mozilla/5.0 (Windows NT 5.2; rv:2.0.1) Gecko/20100101 Firefox/4.0.1' -S -O /dev/null 2>&1 >/dev/null"
  `#{wget} && #{wget}`
end

CONFIG['cookies'] ||= {}
File.readlines(COOKIES_PATH).each do |line|
  data = line.split("\t")
  CONFIG['cookies'][data[5]] = data[6].strip if data[0] === '.facebook.com'
end
