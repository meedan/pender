require 'aws-sdk-s3'

module Pender
  class Store

    def self.current
      RequestStore.store[:store] ||= Pender::Store.new
    end

    def self.current=(store)
      RequestStore.store[:store] = store
    end

    def self.public_policy(bucket)
      {:Version=>"2012-10-17", :Statement=>[{:Effect=>"Allow", :Principal=>"*", :Action=>"s3:GetObject", :Resource=>"arn:aws:s3:::#{bucket}/*"}]}.to_json
    end

    def initialize
      @storage = {}
      %w(endpoint access_key secret_key bucket bucket_region video_bucket video_asset_path medias_asset_path).each do |key|
        @storage[key] = PenderConfig.get("storage_#{key}")
      end

      config = {
        endpoint: @storage.dig('endpoint'),
        access_key_id: @storage.dig('access_key'),
        secret_access_key: @storage.dig('secret_key'),
        force_path_style: true,
        region: @storage.dig('bucket_region')
      }
      @client = Aws::S3::Client.new(config)
      @resource = Aws::S3::Resource.new(client: @client)
      create_buckets
    end

    def create_buckets
      [bucket_name, video_bucket_name].each do |name|
        bucket = @resource.bucket(name)
        unless bucket.exists?
          bucket.create
        end
        @client.put_bucket_policy(policy: Pender::Store.public_policy(name), bucket: name) unless Rails.env.production?
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

    def key(id, type = '')
      type.blank? ? id : "#{id}.#{type}"
    end

    def bucket_name
      "#{@storage.dig('bucket')}#{ENV['TEST_ENV_NUMBER']}"
    end

    def video_bucket_name
      video_bucket = @storage.dig('video_bucket')
      video_bucket ? "#{video_bucket}#{ENV['TEST_ENV_NUMBER']}" : bucket_name
    end

    def storage_path(data = 'medias')
      bucket = (data == 'medias') ? bucket_name : video_bucket_name
      @storage.dig("#{data}_asset_path") || "#{@storage.dig('endpoint')}/#{bucket}/#{data}"
    end

    def exist?(id, type)
      bucket = @resource.bucket(bucket_name)
      bucket.object(key(id, type)).exists?
    end

    def read(id, type = '')
      data = get(id, type)
      return unless data
      data = data.body.read
      type == :json ? JSON.parse(data).with_indifferent_access : data
    end

    def get(id, type = '')
      begin
        @client.get_object(bucket: bucket_name, key: key(id, type))
      rescue Aws::S3::Errors::NoSuchKey
        nil
      end
    end

    def store_object(file_key, content, key_prefix = '')
      content_type = Rack::Mime.mime_type(File.extname(file_key))
      @client.put_object(
        key: key_prefix + file_key,
        body: content,
        bucket: bucket_name,
        content_type: content_type
      )
    end


    def write(id, type, content)
      content = JSON.pretty_generate(content) if type == :json
      store_object(key(id, type), content)
    end

    def upload_video_folder(local_path)
      response = nil
      key_prefix = "video/#{File.basename(local_path)}/"
      Dir.glob(local_path + '/*').each do |filepath|
        File.open(filepath, 'rb') do |content|
          response = store_object(File.basename(filepath), content, key_prefix)
        end
      end
      response.to_h
    end

    def delete(id, *types)
      objects = []
      types.each do |type|
        objects << { key: key(id, type)}
      end
      @client.delete_objects(bucket: bucket_name, delete: { objects: objects })
    end
  end
end
