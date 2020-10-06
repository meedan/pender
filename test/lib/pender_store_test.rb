require_relative '../test_helper'

class PenderStoreTest < ActiveSupport::TestCase

  test "should upload folder to S3" do
    local_folder = File.join(Rails.root, 'test', 'data')
    files = Dir.glob(local_folder + '/*')

    storage = Pender::Store.current
    storage.upload_video_folder(local_folder)
    files.each do |f|
      local_file = File.open(f).read
      filename = File.basename(f)
      assert_equal local_file, storage.read("video/data/#{filename}")
    end
  end
end
