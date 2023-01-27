
require 'aws-sdk-s3'

module Pender
  class AwsS3Client
    class << self
      def get_client
        config = {
          endpoint: PenderConfig.get('storage_endpoint'),
          access_key_id: PenderConfig.get('storage_access_key'),
          secret_access_key: PenderConfig.get('storage_secret_key'),
          force_path_style: true,
          region: PenderConfig.get('storage_bucket_region'),
        }
        Aws::S3::Client.new(config)
      end
    end
  end
end
