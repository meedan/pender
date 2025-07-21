require 'test_helper'

class MediaApifyItemTest < ActiveSupport::TestCase
  def setup
    @error = StandardError.new('Something went wrong')
    @apify_url = 'https://api.apify.com/v2/acts/apify~facebook-posts-scraper'
  end

  test '.handle_apify_error works with array parsed_response' do
    parsed_response = [{ 'url' => 'https://example.com', 'error' => 'error', 'errorDescription' => 'desc' }]
    PenderSentry.stub :notify, true do
      Rails.logger.stub :warn, true do
        assert_nothing_raised do
          Media.handle_apify_error(@error, @apify_url, parsed_response)
        end
      end
    end
  end

  test '.handle_apify_error works with nil parsed_response' do
    parsed_response = nil
    PenderSentry.stub :notify, true do
      Rails.logger.stub :warn, true do
        assert_nothing_raised do
          Media.handle_apify_error(@error, @apify_url, parsed_response)
        end
      end
    end
  end

  test '.handle_apify_error fails with hash parsed_response' do
    parsed_response = { 'url' => 'https://example.com', 'error' => 'error', 'errorDescription' => 'desc' }
    PenderSentry.stub :notify, true do
      Rails.logger.stub :warn, true do
        assert_nothing_raised do
          Media.handle_apify_error(@error, @apify_url, parsed_response)
        end
      end
    end
  end
end
