require 'pender/exception'

module ProviderTwitter
  extend ActiveSupport::Concern

  class ApiError < StandardError; end

  BASE_URI = "https://api.twitter.com/2/"

  def oembed_url(_ = nil)
    "https://publish.twitter.com/oembed?url=#{self.url}"
  end

  private

  def replace_subdomain_pattern(original_url)
    original_url.gsub(/:\/\/.*\.twitter\./, '://twitter.')
  end

  def format_oembed_data(type, oembed_data)
    embed_data ||= {}
    return { error: oembed_data[:errors]} unless oembed_data[:errors].blank?
    html = oembed_data.dig('html')
    doc = Nokogiri::HTML(html)
    data = {}
    if type == 'profile'
      data = {
        author_name: doc.css("a").text.gsub('Tweets by ', '').strip
      }
    elsif type == 'item'
      blockquote = doc.at("blockquote.twitter-tweet")
      if blockquote
        text = blockquote.at("p").text
        data = {
          title: text.squish,
          description: text.squish,
          published_at: extract_published_at(blockquote),
          html: html,
          author_url: oembed_data.dig('author_url'),
          author_name: oembed_data.dig('author_name'),
        }
      end
    end
    data
  end

  def extract_published_at(blockquote)
    begin
      date_text = blockquote.css("a").last&.text
      Date.parse(date_text)
    rescue
      nil
    end
  end
end
