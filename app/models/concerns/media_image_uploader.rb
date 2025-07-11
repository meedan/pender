class MediaImageUploader
  IMAGE_ATTRIBUTES = [:author_picture, :picture].freeze

  def initialize(media)
    @media = media
  end

  def upload_images
    IMAGE_ATTRIBUTES.each do |attribute|
      MediaImage.new(@media, attribute).upload
    end
  end
end
