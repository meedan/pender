require 'aws-sdk-s3'

module Pender
  class Store

    def self.current
      RequestStore.store[:store] ||= Pender::Store.new
    end

    def self.current=(store)
      RequestStore.store[:store] = store
    end

    def initialize(api_key_id = nil)
      @storage = PenderConfig.get('storage', {})
      Aws.config.update(
        endpoint: @storage.dig('endpoint'),
        access_key_id: @storage.dig('access_key'),
        secret_access_key: @storage.dig('secret_key'),
        force_path_style: true,
        region: @storage.dig('bucket_region')
      )
      @resource = Aws::S3::Resource.new
    end


    def create_buckets
      [bucket_name, video_bucket_name].each do |name|
        bucket = @resource.bucket(name)
        unless bucket.exists?
          bucket.create
        end
      end
    end

    def destroy_buckets
      [bucket_name, video_bucket_name].each do |name|
        bucket = @resource.bucket(name)
        if bucket.exists?
          bucket.objects.each { |obj| obj.delete }
          bucket.delete
        end
      end
    end

    def key(id, type)
      "#{id}.#{type}"
    end

    def bucket_name
      "#{@storage.dig('bucket')}#{ENV['TEST_ENV_NUMBER']}"
    end

    def video_bucket_name
      video_bucket = @storage.dig('video_bucket')
      video_bucket ? "#{video_bucket}#{ENV['TEST_ENV_NUMBER']}" : bucket_name
    end

    def exist?(id, type)
      bucket = @resource.bucket(bucket_name)
      bucket.object(key(id, type)).exists?
    end

    def read(id, type)
      data = get(id, type)
      return unless data
      data = data.body.read
      type == :json ? JSON.parse(data).with_indifferent_access : data
    end

    def get(id, type)
      client = Aws::S3::Client.new
      begin
        client.get_object(bucket: bucket_name, key: key(id, type))
      rescue Aws::S3::Errors::NoSuchKey
        nil
      end
    end

    def write(id, type, content)
      content = JSON.pretty_generate(content) if type == :json
      content_type = type == :json ? 'application/json' : 'text/html'
      client = Aws::S3::Client.new
      client.put_object(
        key: key(id, type),
        body: content,
        bucket: bucket_name,
        content_type: content_type
      )
    end

    def upload_video_folder(local_path)
      response = nil
      key_prefix = "video/#{File.basename(local_path)}/"
      client = Aws::S3::Client.new
      Dir.glob(local_path + '/*').each do |filepath|
        File.open(filepath, 'rb') do |file|
          content_type = Rack::Mime.mime_type(File.extname(filepath))
          response = client.put_object(
            key: key_prefix + File.basename(filepath),
            body: file,
            bucket: video_bucket_name,
            content_type: content_type
          )
        end
      end
      response.to_h
    end

    def delete(id, *types)
      objects = []
      types.each do |type|
        objects << { key: key(id, type)}
      end
      client = Aws::S3::Client.new
      client.delete_objects(bucket: bucket_name, delete: { objects: objects })
    end
  end
end
