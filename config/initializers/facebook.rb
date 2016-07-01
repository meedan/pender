# Login on Facebook and store the cookie
username = CONFIG['facebook_user']
password = CONFIG['facebook_password']
wget = "wget 'https://www.facebook.com/login.php?login_attempt=1' --post-data 'email=#{username}&pass=#{password}' --no-check-certificate --keep-session-cookies --save-cookies=/tmp/fbcookies --load-cookies=/tmp/fbcookies -U 'Mozilla/5.0 (Windows NT 5.2; rv:2.0.1) Gecko/20100101 Firefox/4.0.1' -S -O /dev/null 2>&1 >/dev/null"
`rm -f /tmp/fbcookies && #{wget} && #{wget}`
CONFIG['cookies'] ||= {}
File.readlines('/tmp/fbcookies').each do |line|
  data = line.split("\t")
  CONFIG['cookies'][data[5]] = data[6].strip if data[0] === '.facebook.com'
end
FileUtils.rm_rf('/tmp/fbcookies')
