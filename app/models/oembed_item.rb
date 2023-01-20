require 'error_codes'

class OembedItem
  def initialize(request_url, oembed_url)
    @request_url = request_url
    @oembed_uri = construct_absolute_path(request_url, oembed_url)

    @data = {}.with_indifferent_access
    @data[:raw] = { oembed: nil }
  end

  def get_data
    return data if oembed_uri.blank?

    handle_exceptions(StandardError) do
      response = get_oembed_data_from_url(oembed_uri)
      @data[:raw][:oembed] = parse_oembed_response(response)
    end
    data
  end

  attr_reader :oembed_uri

  private

  attr_reader :data, :request_url

  def get_oembed_data_from_url(uri, attempts: 0)
    response = nil
    http = Net::HTTP.new(uri.host, uri.inferred_port)
    http.use_ssl = uri.scheme == 'https'

    headers = { 'User-Agent' => 'Mozilla/5.0 (compatible; Pender/0.1; +https://github.com/meedan/pender)' }.merge(RequestHelper.get_cf_credentials(uri))
    request = Net::HTTP::Get.new(uri.request_uri, headers)
    response = http.request(request)

    if attempts < 5 && RequestHelper::REDIRECT_HTTP_CODES.include?(response.code)
      response = get_oembed_data_from_url(construct_absolute_path(request_url, response.header['location']), attempts: attempts + 1)
    end
    response
  end

  def parse_oembed_response(response)
    return if response.nil? || response.body.blank?

    oembed_json = {}
    begin
      oembed_json = JSON.parse(response.body)
      if oembed_json['html'].present?
        doc = Nokogiri::HTML oembed_json['html']
        # Discard the oEmbed's HTML fragment in the following cases:
        # - The script.src URL is not HTTPS
        # - The iframe.src response includes X-Frame-Options = DENY or SAMEORIGIN
        oembed_json['html'] = '' if invalid_html_script?(doc)
        oembed_json['html'] = '' if invalid_html_iframe?(doc)
      end
    rescue JSON::ParserError => error
      oembed_json.merge!({ error: { message: response.body, code: LapisConstants::ErrorCodes::const_get('INVALID_VALUE') } })
      Rails.logger.warn level: 'WARN', message: '[Parser] Could not parse `oembed` data as JSON', url: request_url, oembed_url: oembed_uri&.to_s, error_class: error.class, error_message: error.message, response_code: response.code
    end
    oembed_json
  end

  def invalid_html_script?(doc)
    script_tag = doc.at_css('script')
    return if script_tag.nil? || script_tag.attr('src').nil?

    uri = RequestHelper.parse_url(script_tag.attr('src'))
    !(uri.scheme == 'https')
  end

  def invalid_html_iframe?(doc)
    iframe_tag = doc.at_css('iframe')
    return if iframe_tag.nil? || iframe_tag.attr('src').nil?

    uri = RequestHelper.parse_url(iframe_tag.attr('src'))
    return if uri.hostname.match(/^(www\.)?youtube\.com/)

    response = Net::HTTP.get_response(uri)
    response&.code&.to_s == '200' && ['DENY', 'SAMEORIGIN'].include?(response.header['X-Frame-Options'])
  end

  def construct_absolute_path(request_url, _oembed_url)
    begin
      RequestHelper.parse_url(RequestHelper.absolute_url(request_url, _oembed_url))
    rescue Addressable::URI::InvalidURIError, TypeError => e
      nil
    end
  end

  def handle_exceptions(exception)
    begin
      yield
    rescue exception => error
      PenderAirbrake.notify(error, oembed_url: oembed_uri&.to_s, oembed_data: data )
      code = LapisConstants::ErrorCodes::const_get('INVALID_VALUE')
      @data.merge!(error: { message: "#{error.class}: #{error.message}", code: code })
      Rails.logger.warn level: 'WARN', message: '[Parser] Could not parse oembed data', oembed_url: oembed_uri&.to_s, code: code, error_class: error.class, error_message: error.message
      return
    end
  end
end
