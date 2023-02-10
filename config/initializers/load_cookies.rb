require 'cookie_loader'
require 'pender_config'

CookieLoader.load_from(PenderConfig.get('cookies_file_path') || 'config/cookies.txt')
