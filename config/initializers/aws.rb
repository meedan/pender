require 'aws-sdk-s3'
require 'pender_store'

Aws.config.update(
  endpoint: CONFIG.dig('storage', 'endpoint'),
  access_key_id: CONFIG.dig('storage', 'access_key'),
  secret_access_key: CONFIG.dig('storage', 'secret_key'),
  force_path_style: true,
  region: CONFIG.dig('storage', 'bucket_region')
)

resource = Aws::S3::Resource.new
[Pender::Store.bucket_name, Pender::Store.video_bucket_name].each do |name|
  bucket = resource.bucket(name)
  unless bucket.exists?
    bucket.create
  end
end
