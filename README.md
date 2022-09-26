# Pender

<a href="https://codeclimate.com/repos/5715585edb5e930072004cc5/feed"><img src="https://codeclimate.com/repos/5715585edb5e930072004cc5/badges/f5868b936888747f319f/gpa.svg" /></a>
[![Issue Count](https://codeclimate.com/repos/5715585edb5e930072004cc5/badges/f5868b936888747f319f/issue_count.svg)](https://codeclimate.com/repos/5715585edb5e930072004cc5/feed)
[![Test Coverage](https://codeclimate.com/repos/5715585edb5e930072004cc5/badges/f5868b936888747f319f/coverage.svg)](https://codeclimate.com/repos/5715585edb5e930072004cc5/coverage)
[![Travis](https://travis-ci.org/meedan/pender.svg?branch=develop)](https://travis-ci.org/meedan/pender/)

Pender is a service for link parsing, archiving and rendering. It is one of the services that supports [Check](https://meedan.com/check), an open source platform for collaborative fact-checking and media annotation.

## General Info

The url is visited, parsed and the data found is used to create a media and its attributes. The data can be obtained by API or parsing directly the HTML.

These are the specific parsers supported:
* Twitter profiles
* Twitter posts
* YouTube profiles (users and channels)
* YouTube videos
* Facebook profiles (users and pages)
* Facebook posts (from pages and users)
* Instagram posts
* Instagram profiles
* TikTok posts
* TikTok profiles
* Dropbox links

Besides the specific parsers Pender can parse any link with an oEmbed endpoint or metatags.

### Archivers supported

* Archive.is
* Archive.org
  * This archiver requires `archive_org_access_key` and `archive_org_secret_key` on `config/config.yml` file to be enabled. Get your account’s keys at https://archive.org/account/s3.php
* Perma.cc
  * This archiver requires a `perma_cc_key` on `config/config.yml` file to be enabled. Get your account key at https://perma.cc
* Video Archiver
  * Pender uses `youtube-dl` to download videos from any page
  * Many requests in a short period of time to a domain (~20 requests/min) can lead to IP blocking.
  * To avoid IP blocking when downloading Youtube videos Pender can use a proxy. We have tested two proxies:
    * Oxylabs (recommended)
    * Luminati is not recommended for downloading videos: https://github.com/ytdl-org/youtube-dl/issues/23521

## Setup

To run Pender, follow these steps:

```
$ git clone https://github.com/meedan/pender.git
$ cd pender
$ find -name '*.example' | while read f; do cp "$f" "${f%%.example}"; done
$ docker-compose build
$ docker-compose up --abort-on-container-exit
```
Open http://localhost:3200/api-docs/index.html to access Pender API directly.

### Setting Cookies for Requests

We send cookies with certain requests that require logged-in users (e.g. Instagram, TikTok).

**In development**
To provide these for development, log in on your browser and copy the cookie information to `config/cookies.txt`. The location of this file can also be configured as `cookies_file_path` in `config.yml`

To do this easily in Chrome:
1. Install the [Get cookies.txt](https://chrome.google.com/webstore/detail/get-cookiestxt/bgaddhkoddajcdgocldbbfleckgcbcid) browser extension
1. Log into the website (e.g. instagram.com)
1. Using the browser extension, export cookies on the page you want to view
1. Replace the entries in `config/cookies.txt` with the downloaded `cookies.txt`

**Note**: If you do install this extension, consider doing it on a limited Chrome profile since it requires read and write permission for all websites.

**In deployed environments**
Deployed environment cookies are stored in S3. To update them, use steps 1-3 above and then update the remote file in AWS. The path to this file can be found for each environment in [SSM](https://meedan.atlassian.net/wiki/spaces/ENG/pages/1126694913/How+to+get+and+set+configuration+values+and+secrets+on+SSM).

## API

To make requests to the API, you must set a request header with the value of the configuration option `authorization_header` - by default, this is `X-Pender-Token`. The value of that header should be the API key that you have generated using `bundle exec rake lapis:api_keys:create`, or any API key that was given to you.

### GET /api/about

Use this method in order to get the archivers enabled on this application

**Parameters**

**Response**

200: Information about the application
```json
{
  "type": "about",
  "data": {
    "name": "Keep",
    "version": "v0.68.0",
    "archivers": [
      {
        "key": "archive_org",
        "label": "Archive.org"
      }
    ]
  }
}
```

401: Access denied
```json
{
  "type": "error",
  "data": {
    "message": "Unauthorized",
    "code": 1
  }
}
```

### GET /api/medias.format

Get parseable data for a given URL, that can be a post or a profile, from different providers. `format` can be one of the following, see responses below:
- `html`
- `js`
- `oembed`
- `json`

**Parameters**

* `url`: URL to be parsed/rendered _(required)_
* `refresh`: boolean to indicate that Pender should re-fetch and re-parse the URL if it already exists in its cache _(optional)_
* `archivers`: list of archivers to target. Possible values:
  * empty: the URL will be archived in all available archivers
  * `none`: the URL will not be archived
  * string with a list of archives separated by commas: the URL will be archived only on specified archivers

**Response**

**HTML**

A card-representation of the URL, like the ones below:

![YouTube](screenshots/youtube.png?raw=true "YouTube")
![Facebook](screenshots/facebook.png?raw=true "Facebook")
![Twitter](screenshots/twitter.png?raw=true "Twitter")

**JavaScript**

An embed code for the item, which should be called this way:

```html
<script src="http://pender.host/api/medias.js?url=https%3A%2F%2Fwww.youtube.com%2Fchannel%2FUCEWHPFNilsT0IfQfutVzsag"></script>
```

**oEmbed**

An oEmbed representation of the item, e.g.:

```json
{
  "type": "rich",
  "version": "1.0",
  "title": "Porta dos Fundos",
  "author_name": "PortadosFundos",
  "author_url": "https://www.youtube.com/channel/UCEWHPFNilsT0IfQfutVzsag",
  "provider_name": "youtube",
  "provider_url": "http://www.youtube.com",
  "thumbnail_url": "https://yt3.ggpht.com/-xle954Zxs4E/AAAAAAAAAAI/AAAAAAAAAAA/geYaRfTQ0FY/s88-c-k-no-rj-c0xffffff/photo.jpg",
  "html": "\u003ciframe src=\"http://localhost:3005/api/medias.html?url=https%3A%2F%2Fwww.youtube.com%2Fchannel%2FUCEWHPFNilsT0IfQfutVzsag\" width=\"600\" height=\"300\" scrolling=\"no\" seamless\u003eNot supported\u003c/iframe\u003e",
  "width": 600,
  "height": 300
}
```

**JSON**

200: Parsed data
```json
{
  "type": "media",
  "data": {
    "url": "https://www.youtube.com/user/MeedanTube",
    "provider": "youtube",
    "type": "profile",
    "title": "MeedanTube",
    "description": "",
    "published_at": "2009-03-06T00:44:31.000Z",
    "picture": "https://yt3.ggpht.com/-MPd3Hrn0msk/AAAAAAAAAAI/AAAAAAAAAAA/I1ftnn68v8U/s88-c-k-no/photo.jpg",
    "username": "MeedanTube",
    "author_url": "https://www.youtube.com/user/MeedanTube",
    "author_name": "MeedanTube",
    "raw": {
      "metatags": [],
      "oembed": {},
      "api": {}
    },
    "schema": {},
    "html": "",
    "embed_tag": "<embed_tag>"
  }
}
```

400: URL not provided
```json
{
  "type": "error",
  "data": {
    "message": "Parameters missing",
    "code": 2
  }
}
```

401: Access denied
```json
{
  "type": "error",
  "data": {
    "message": "Unauthorized",
    "code": 1
  }
}
```

408: Timeout
```json
{
  "type": "error",
  "data": {
    "message": "Timeout",
    "code": 10
  }
}
```

429: API limit reached
```json
{
  "type": "error",
  "data": {
    "message": 354, // Waiting time in seconds
    "code": 11
  }
}
```

409: Conflict
```json
{
  "type": "error",
  "data": {
    "message": "This URL is already being processed. Please try again in a few seconds.",
    "code": 9
  }
}
```

### POST /api/medias

Create background jobs to parse each URL and notify the caller with the result

**Parameters**

* `url`: URL(s) to be parsed. Can be an array of URLs, a single URL or a list of URLs separated by a commas
 _(required)_
* `refresh`: Force a refresh from the URL instead of the cache. Will be applied to all URLs
* `archivers`: List of archivers to target. Can be empty, `none` or a list of archives separated by commas. Will be applied to all URLs

**Response**

200: Enqueued URLs
```json
{
  "type": "success",
  "data": {
    "enqueued": [
      "https://www.youtube.com/user/MeedanTube",
      "https://twitter.com/meedan"
    ],
    "failed": [

    ]
  }
}
```

401: Access denied
```json
{
  "type": "error",
  "data": {
    "message": "Unauthorized",
    "code": 1
  }
}
```

### DELETE|PURGE /api/medias

Clears the cache for the URL(s) passed as parameter.

**Parameters**

* `url`: URL(s) to be deleted, either as an array or a string with one URL or multiple URLs separated by a space  _(required)_

**Response**

200: Success
```json
{
  "type": "success",
}
```

401: Access denied
```json
{
  "type": "error",
  "data": {
    "message": "Unauthorized",
    "code": 1
  }
}
```

## Webhook Notification

The metrics and archiving feature are asynchronous events. Pender can notify your application after it requests the metrics or sends the URLs for archiving.

Pender sends the `url`, `type` and the information associated with the event. The webhook endpoint should have an associated URL (e.g., http://api:3000/api/webhooks/keep) and a token. These information should be added to API key's `application_settings`: `api_key.application_settings = {:webhook_url=>"http://api:3000/api/webhooks/keep", :webhook_token=>"somethingsecret"}`

## Rake tasks

There are rake tasks for a few tasks (besides Rails' default ones). Run them this way: `bundle exec rake <task name>`

* `test:coverage`: Run all tests and calculate test coverage
* `application=<application name> lapis:api_keys:create`: Create a new API key for an application
* `lapis:api_keys:delete_expired`: Delete all expired keys
* `lapis:error_codes`: List all error codes that this application can return
* `lapis:licenses`: List the licenses of all libraries used by this project
* `lapis:client:ruby`: Generate a client Ruby gem, that allows other applications to communicate and test this service
* `lapis:client:php`: Generate a client PHP library, that allows other applications to communicate and test this service
* `lapis:docs`: Generate the documentation for this API, including models and controllers diagrams, Swagger, API endpoints, licenses, etc.
* `lapis:docker:run`: Run the application in Docker
* `lapis:docker:shell`: Enter the Docker container

## How to add a new parser

* Add a new file at `app/models/concerns/parser/<provider>_<type>.rb` (example... `provider` could be `facebook` and type could be `post` or `profile`)
* Include the class in the `PARSERS` array in `app/models/media.rb`
* It should return at least `published_at`, `username`, `title`, `description` and `picture`
* If `type` is `item`, it should also return the `author_url` and `author_picture`
* The skeleton should look like this:

```ruby
module Parser
  class <Provider><Type> < Base  
    class << self
      def type
        '<provider>_<type>'.freeze
      end
  
      def patterns
        [<list of URL patterns>]
      end
            
      def ignored_urls
        # Optional method to specify disallowed URLs
        # Should return an array in format:
        # [
        #   {
        #     pattern: /^https:\/\/www\.instagram\.com\/accounts\/login/,
        #     reason: :login_page
        #   },
        # ]
      end
    end

    private    

    def parse_data_for_parser(doc, original_url)
      # Populate `@parsed_data` with information and return parsed_data at the end of the function
      # `@parsed_data` is a hash whose key is the attribute and the value is... the value
    end

    def oembed_url(doc)
      # Optional method to define an Oembed URL, will default to looking in HTML in Parser::Base
      # Passed to OembedItem
    end
  end
end
```

If shared behavior is needed between parsers of the same provider, make a provider class as a concern and include it in the class.
See ProviderInstagram, ProviderYoutube, ProviderFacebook, ProviderTwitter, or ProviderTiktok for examples.

## How to add a new archiver

* Add a new file at `app/models/concerns/media_<name>_archiver.rb`
* Include the class in `app/models/media.rb`
* It should have a method `archive_to_<name>`
* It should call method `Media.declare_archiver`, saying the URL patterns it supports (using the `only` modifier) or the URL patterns it doesn't support (using the `except` modifier)
* The skeleton should look like this:

```ruby
module Media<Name>Archiver
  extend ActiveSupport::Concern

  included do
    Media.declare_archiver('<name>', [<list of URL patterns as regular expressions>], :only) # Or :except instead of :only
  end

  def archive_to_<name>
    # Archive and then update cache (if needed) and call webhook (if needed)
    Media.notify_webhook_and_update_cache(<name>, url, data, key_id)
  end
end
```

## Profiling

It's possible to profile Pender in order to look for bottlenecks, slownesses, performance issues, etc. To profile a Rails application it is vital to run it using production like settings (cache classes, cache view lookups, etc.). Otherwise, Rail's dependency loading code will overwhelm any time spent in the application itself. The best way to do this is create a new Rails environment. So, follow the steps below:

* Copy `config/environments/profile.rb.example` to `config/environments/profile.rb`
* Make sure you have a `profile` environment setup on `config/config.yml` and `config/database.yml`
* Run `bundle exec rake db:migrate RAILS_ENV=profile` (only needed at the first time)
* Create an API key for the profile environment: `bundle exec rake lapis:api_keys:create RAILS_ENV=profile`
* Start the server in profile mode: `bundle exec rails s -e profile -p 3005`
* Make a request you want to profile using the key you created before: `curl -XGET -H 'X-Pender-Token: <API key>' 'http://localhost:3005/api/medias.json?url=https://twitter.com/meedan/status/773947372527288320'`
* Check the results at `tmp/profile`

_Everytime you make a new request, the results on tmp/profile are overwritten_

We can also run performance tests. It calculates the amount of time taken to validate, instantiate and parse a link for each of the supported types/providers. In order to do that, run: `bundle exec rake test:performance`. It will generate a CSV at `tmp/performance.csv`, so that you can compare the time take for each provider.

## Observability

We use Honeycomb for monitoring information about our application. It is currently configured to report to local console
and not report to Honeycomb in test and development environments (see `initializers/open_telemetry.rb`), but it is possible to 
also report data from your local environment for troubleshooting purposes.

If you would like to send data to Honeycomb from your local machine, do the following:
1. Make sure that the `otlp` prefixed values are set in `config.yml` following `config.yml.example`
1. In the config key `otel_exporter_otlp_headers`, set `x-honeycomb-team` to a Honeycomb API key for the Development environment (a sandbox where we put anything). This can be found in the [Honeycomb web interface](https://ui.honeycomb.io/meedan/environments/dev/api_keys). To track your own reported info, be sure to set the `otel_resource_attributes.developer.name` key in `config.yml` to your own name or unique identifier (e.g. `christa`). You will need this to filter information on Honeycomb.
1. Uncomment the guard statement that logs to console in `initializers/open_telemetry.rb` in dev and test environments
1. Restart the server
1. See reported information in Development environment on Honeycomb


## Credits

Meedan (hello@meedan.com)
