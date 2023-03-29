require 'pender/aws_s3_client'
require 'pender_sentry'

class CookieLoader
  class FilePathError < StandardError; end
  class S3DownloadError < StandardError; end

  class << self
    def load_from(cookies_path)
      CONFIG['cookies'] = {} if CONFIG['cookies'].nil?
      begin
        raise FilePathError.new('Path not provided') unless cookies_path

        tmpfile = nil
        if cookies_path.start_with?('s3://')
          parts = cookies_path.gsub('s3://',  '').split('/')
          raise FilePathError.new('S3 path unparseable') unless parts.length == 2
          
          tmpfile = Tempfile.new('cookies.txt')
          response = Pender::AwsS3Client.get_client.get_object(bucket: parts[0], key: parts[1], response_target: tmpfile.path)
          raise S3DownloadError.new('Unsuccessful response from S3') unless response.successful?
          raise S3DownloadError.new('Downloaded file from S3 is empty') unless tmpfile.size > 0
        end
        raise FilePathError.new('No file found at path') unless File.file?(tmpfile&.path || cookies_path)

        File.readlines(tmpfile&.path || cookies_path).each do |line|
          data = line.split("\t")
          next if data[0].start_with?('#')
          CONFIG['cookies'][data[0]] ||= {}
          CONFIG['cookies'][data[0]][data[5]] = data[6].strip if data[6]
        end
        CONFIG['cookies']
      rescue StandardError => error
        PenderSentry.notify(error, provided_path: cookies_path)
        Rails.logger.warn(message: 'Problem setting cookies', provided_path: cookies_path, error_class: error.class, error_message: error.message)
        false
      ensure
        tmpfile.close if tmpfile
        tmpfile.unlink if tmpfile
      end
    end
  end
end
