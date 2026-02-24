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

  def twitter_oembed_data(doc, url)
    doc = refetch_html(url) if doc.nil?
    OembedItem.new(url, oembed_url(doc)).get_data
  end

  def format_oembed_data(type, oembed)
    oembed ||= {}
    return { error: oembed[:errors]} unless oembed[:errors].blank?
    html = oembed.dig('html')
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
          author_url: oembed.dig('author_url'),
          author_name: oembed.dig('author_name'),
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
