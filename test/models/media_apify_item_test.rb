require 'test_helper'

class MediaApifyItemTest < ActiveSupport::TestCase
  def setup
    @error = Pender::Exception::ApifyResponseError.new('Something went wrong')
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

  test '.handle_apify_error works with hash parsed_response' do
    parsed_response = { 'url' => 'https://example.com', 'error' => 'error', 'errorDescription' => 'desc' }
    PenderSentry.stub :notify, true do
      Rails.logger.stub :warn, true do
        assert_nothing_raised do
          Media.handle_apify_error(@error, @apify_url, parsed_response)
        end
      end
    end
  end

  test '.handle_apify_error handles data-not-found error with ApifyDataNotFoundError' do
    data_not_found_error = {
      "error" =>{
        "message" => "Apify data not found or link is inaccessible"
        },
      "external_id" => "DQCLicaDWgN",
      "provider" => "instagram",
      "raw" => {
        "metatags" => []
        },
      "type" => "item",
      "url" => "https://www.instagram.com/reel/DQCLicaDWgN"
    }
    @error = Pender::Exception::ApifyResponseError.new(data_not_found_error["error"]["message"])

    error_sent_to_sentry = nil
    mock = Minitest::Mock.new
    mock.expect :call, true do |error, **kwargs|
      error_sent_to_sentry = error
      true
    end

    PenderSentry.stub :notify, mock do
      Rails.logger.stub :warn, true do
        assert_nothing_raised do
          Media.handle_apify_error(@error, @apify_url, data_not_found_error)
        end
      end
    end

    assert_kind_of Pender::Exception::ApifyDataNotFoundError, error_sent_to_sentry
    assert_equal data_not_found_error["error"]["message"], error_sent_to_sentry.message
    mock.verify
  end

  test '.handle_apify_error handles data not available error with ApifyDataNotAvailable' do
    data_not_available_error = {
      "error" => "not_available",
      "errorDescription" => "This content isn't available because the owner only shared it with a small group",
      "url" => "https://www.facebook.com/100001678251190/posts/25194011360238125?mibextid=rS40aB7S9Ucbxw6v",
    }

    @error = Pender::Exception::ApifyResponseError.new(data_not_available_error["errorDescription"])

    error_sent_to_sentry = nil
    mock = Minitest::Mock.new
    mock.expect :call, true do |error, **kwargs|
      error_sent_to_sentry = error
      true
    end

    PenderSentry.stub :notify, mock do
      Rails.logger.stub :warn, true do
        assert_nothing_raised do
          Media.handle_apify_error(@error, @apify_url, data_not_available_error)
        end
      end
    end

    assert_kind_of Pender::Exception::ApifyDataNotAvailableError, error_sent_to_sentry
    assert_equal data_not_available_error["errorDescription"], error_sent_to_sentry.message
    mock.verify
  end

  test '.handle_apify_error handles actor-memory-limit-exceeded error with ApifyActorMemoryError' do
    actor_memory_limit_exceeded_error = {
      "message" => "By launching this job you will exceed the memory limit of 32768MB for all your Actor runs and builds (currently used: 32768MB, requested: 4096MB). Please consider upgrading or purchasing extra memory as an add-on at https://console.apify.com/billing/subscription to increase your Actor memory limit.",
      "type" => "actor-memory-limit-exceeded"
    }
    @error = Pender::Exception::ApifyResponseError.new(actor_memory_limit_exceeded_error["message"])

    error_sent_to_sentry = nil
    mock = Minitest::Mock.new
    mock.expect :call, true do |error, **kwargs|
      error_sent_to_sentry = error
      true
    end

    PenderSentry.stub :notify, mock do
      Rails.logger.stub :warn, true do
        assert_nothing_raised do
          Media.handle_apify_error(@error, @apify_url, actor_memory_limit_exceeded_error)
        end
      end
    end

    assert_kind_of Pender::Exception::ApifyActorMemoryError, error_sent_to_sentry
    assert_equal actor_memory_limit_exceeded_error["message"], error_sent_to_sentry.message
    mock.verify
  end
end
