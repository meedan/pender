require 'aws-sdk-s3'

def filesystem_dir
  File.join('public', 'cache', Rails.env)
end

def get_filesystem_files(dir)
  Dir.glob("#{dir}/*.{html,json}")
end

def get_filesystem_media(path, _id)
  File.read(path)
end

def get_filesystem_id_and_type(path)
  extension = File.extname(path)
  id = File.basename(path, extension)
  type = extension.gsub('.', '')
  [id, type]
end

def cache_dir
  dir = Rails.cache.cache_path
end

def get_cache_files(dir)
  regex = /\A[0-9a-f]{32}\z/i
  Dir.glob(File.join(dir, '**', '*')).select { |file| File.file?(file) && File.basename(file).match(regex)}
end

def get_cache_media(_path, id)
  Rails.cache.read(id)
end

def get_cache_id_and_type(path)
  [File.basename(path), :json]
end

def copy_files(source, files)
  total = files.size
  puts "[#{Time.now}] Copying #{total} files from #{source} to S3..."

  i = 0
  files.in_groups_of(1000, false).each do |batch|
    batch.each do |path|
      begin
        id, type = send("get_#{source}_id_and_type", path)
        unless Pender::Store.exist?(id, type)
          content = send("get_#{source}_media", path, id)
          Pender::Store.write(id, type, content)
        end
        i += 1
        print "#{i}/#{total}\r"
        $stdout.flush
      rescue StandardError => e
        @failed[source] << {error: e, path: path}
      end
    end
  end
  failed_size = @failed[source].size
  puts "[#{Time.now}] #{total - failed_size} files copied from #{source} to S3."
  puts "[#{Time.now}]   Failed to copy #{failed_size} files."
end

namespace :pender do
  namespace :migrate do
    task move_files_to_s3: :environment do
      @failed = {}
      [:filesystem, :cache].each do |source|
        @failed[source] = []
        dir = send("#{source}_dir")
        unless File.exist?(dir)
          puts "Nothing to do for #{source}. #{dir} was not found"
          next
        end
        puts "[#{Time.now}] Verifying files on #{source} to move to S3..."
        files = send("get_#{source}_files", dir)
        copy_files(source, files)
      end
      @failed.each do |source, list|
        next unless list.size > 0
        list.each do |details|
          puts details
        end
      end
    end
  end
end
