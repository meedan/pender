require 'aws-sdk'
require 'pender_store'

Aws.config.update(
  endpoint: CONFIG.dig('storage', 'endpoint'),
  access_key_id: CONFIG.dig('storage', 'access_key'),
  secret_access_key: CONFIG.dig('storage', 'secret_key'),
  force_path_style: true,
  region: CONFIG.dig('storage', 'bucket_region')
)

resource = Aws::S3::Resource.new
bucket = resource.bucket(Pender::Store.bucket_name)
unless bucket.exists?
  bucket.create
end
