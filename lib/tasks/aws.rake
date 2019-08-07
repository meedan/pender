require 'aws-sdk-s3'

namespace :pender do
  namespace :aws do
    task minio: :environment do
      Aws.config.update(
        endpoint: 'http://minio:9000',
        access_key_id: 'AKIAIOSFODNN7EXAMPLE',
        secret_access_key: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        force_path_style: true,
        region: 'us-east-1'
      )

      rubys3_client = Aws::S3::Client.new

      # put_object operation

      rubys3_client.put_object(
              key: 'testobject',
              body: 'Hello from MinIO!!',
              bucket: 'testbucket',
              content_type: 'text/plain'
      )

      # get_object operation

      rubys3_client.get_object(
               bucket: 'testbucket',
               key: 'testobject',
               response_target: 'download_testobject'
      )

      print "Downloaded 'testobject' as  'download_testobject'. "
    end
  end
end
