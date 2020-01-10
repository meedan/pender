module Pender
  class Store

    def self.key(id, type)
      "#{id}.#{type}"
    end

    def self.bucket_name
      "#{CONFIG.dig('storage', 'bucket')}#{ENV['TEST_ENV_NUMBER']}"
    end

    def self.video_bucket_name
      video_bucket = CONFIG.dig('storage', 'video_bucket')
      video_bucket ? "#{video_bucket}#{ENV['TEST_ENV_NUMBER']}" : self.bucket_name
    end

    def self.exist?(id, type)
      resource = Aws::S3::Resource.new
      bucket = resource.bucket(bucket_name)
      bucket.object(key(id, type)).exists?
    end

    def self.read(id, type)
      data = get(id, type)
      return unless data
      data = data.body.read
      type == :json ? JSON.parse(data).with_indifferent_access : data
    end

    def self.get(id, type)
      client = Aws::S3::Client.new
      begin
        client.get_object(bucket: bucket_name, key: key(id, type))
      rescue Aws::S3::Errors::NoSuchKey
        nil
      end
    end

    def self.write(id, type, content)
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

    def self.upload_video_folder(local_path)
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

    def self.delete(id, *types)
      objects = []
      types.each do |type|
        objects << { key: key(id, type)}
      end
      client = Aws::S3::Client.new
      client.delete_objects(bucket: bucket_name, delete: { objects: objects })
    end
  end
end
