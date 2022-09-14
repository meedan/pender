require 'ids_please'

module Parser
  class FacebookItem < Base
    include ProviderFacebook

    EVENT_URL = /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/events\/(?<id>\w+)(?!.*permalink\/)/
    GROUPS_URL = /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/groups\/(?<profile>[^\/]+)\/permalink\/(?<id>[0-9]+).*/
  
    FACEBOOK_ITEM_URLS = [
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/posts\/(?<id>[0-9]+).*/,
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/photos\/.*a\.([0-9]+)\.([0-9]+)\.(?<user_id>[0-9]+)\/(?<id>[0-9]+)\/.*/,
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/photos\/.*a\.([0-9]+)\.([0-9]+)\.(?<id>[0-9]+)\/([0-9]+).*/,
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/photos\/.*a\.([0-9]+)\/([0-9]+).*/,
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/photos\/.*&album_id=(?<id>[0-9]+).*/,
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/photos\/(?<id>[0-9]+).*/,
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/media\/set\?set=a\.(?<id>[0-9]+)\.([0-9]+)\.([0-9]+).*/,
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/photos\/pcb\.([0-9]+)\/(?<id>[0-9]+).*/,
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/photo(.php)?\/?\?fbid=(?<id>[0-9]+)&set=a\.([0-9]+)(\.([0-9]+)\.([0-9]+))?.*/,
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/photo(.php)?\?fbid=(?<id>[0-9]+)&set=p\.([0-9]+).*/,
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/album.php?\?fbid=(?<id>[0-9]+).*/,
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/videos\/(?<id>[0-9]+).*/,
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/(?<profile>[^\/]+)\/videos\/vb\.([0-9]+)\/(?<id>[0-9]+).*/,
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/permalink.php\?story_fbid=(?<id>[0-9]+)&id=([0-9]+).*/,
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/story.php\?story_fbid=(?<id>[0-9]+)&id=(?<user_id>[0-9]+).*/,
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/livemap(\/.*)?/,
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/watch(\/.*)?/,
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/live\/map(\/.*)?/,
      /^https?:\/\/(?<subdomain>[^\.]+\.)?facebook\.com\/events\/(?<id>[0-9]+)\/permalink\/([0-9]+).*/,
      /^https?:\/\/(www\.)?facebook\.com\/(?<id>[^\/\?]+).*$/,
      GROUPS_URL,
      EVENT_URL
    ]

    class << self
      def type
        'facebook_item'.freeze
      end

      def patterns
        FACEBOOK_ITEM_URLS
      end
    end

    private

    # Main function for class
    def parse_data_for_parser(doc, original_url)
      handle_exceptions(StandardError) do
        grabber = IdsGrabber.new(doc, url, original_url)
        set_data_field('user_uuid', grabber.user_id)
        set_data_field('object_id', grabber.post_id)
        set_data_field('uuid', grabber.uuid)
        set_data_field('external_id', grabber.uuid)
        
        @parsed_data['raw']['crowdtangle'] = get_crowdtangle_data(parsed_data['uuid']) || {}
        if crowdtangle_error = parsed_data.dig('raw', 'crowdtangle', 'error')
          @parsed_data['error'] = crowdtangle_error

          unless doc.nil?
            @parsed_data.merge!(get_opengraph_metadata.reject{|k,v| v.nil? })
            set_data_field('title', get_page_title(doc))
            set_data_field('description', doc.at_css('description')&.content)
          end
        else
          crowdtangle_data = format_crowdtangle_result(parsed_data['raw']['crowdtangle'])
          updated_url = parsed_data.dig('raw', 'crowdtangle', 'posts', 0, 'postUrl')
          @url = updated_url if updated_url && updated_url != url
          @parsed_data.merge!(crowdtangle_data)
        end

        @parsed_data['html'] = html_for_facebook_post(parsed_data.dig('username'), doc, url) || ''
      end

      parsed_data
    end

    def html_for_facebook_post(username, html_page, request_url)
      return unless html_page
      return if set_facebook_privacy_error(html_page, unavailable_page)
      return if username && !['groups', 'flx'].include?(username)
      return unless not_an_event_page && not_a_group_post

      '<script>
      window.fbAsyncInit = function() { FB.init({ xfbml: true, version: "v2.6" }); FB.Canvas.setAutoGrow(); };
      (function(d, s, id) {
        var js, fjs = d.getElementsByTagName(s)[0];
        if (d.getElementById(id)) return;
        js = d.createElement(s); js.id = id;
        js.src = "//connect.facebook.net/en_US/sdk.js";
        fjs.parentNode.insertBefore(js, fjs);
      }(document, "script", "facebook-jssdk"));
      </script>
      <div class="fb-post" data-href="' + request_url + '"></div>'
    end

    def not_a_group_post
      url.match(GROUPS_URL).nil?
    end

    def not_an_event_page
      url.match(EVENT_URL).nil?
    end
  end
end
