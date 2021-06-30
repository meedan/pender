class MoveFilesToS3 < ActiveRecord::Migration[4.2]
  def change
    Rails.cache.write('pender:migrate:move_files_to_s3', nil)
  end
end
