# Pender

[Test Coverage: Overview](https://codeclimate.com/github/meedan/pender)
[Test Coverage: Issues](https://codeclimate.com/github/meedan/pender/issues)
![test](https://github.com/meedan/pender/actions/workflows/ci-test-pr.yml/badge.svg?branch=develop)

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

* Archive.org
  * This archiver requires `archive_org_access_key` and `archive_org_secret_key` on `config/config.yml` file to be enabled. Get your account’s keys at https://archive.org/account/s3.php
* Perma.cc
  * This archiver requires a `perma_cc_key` on `config/config.yml` file or the requesting API key to be enabled. Get your account key at https://perma.cc

## Setup

To set Pender up locally:

```
git clone https://github.com/meedan/pender.git
cd pender
find -name '*.example' | while read f; do cp "$f" "${f%%.example}"; done
```

To run Pender in development mode, follow these steps:

```
$ docker-compose build
$ docker-compose up --abort-on-container-exit
```
Open http://localhost:3200/api-docs/index.html to access Pender API directly.

To run the full test suite of Pender tests locally the way CI runs them:

```
rm .env.test
bin/get_env_vars.sh
docker build . -t pender
docker compose -f docker-test.yml up pender
docker compose -f docker-test.yml exec pender test/setup-parallel
docker compose -f docker-test.yml exec pender bundle exec rake "parallel:test[3]"
docker compose -f docker-test.yml exec pender bundle exec rake "parallel:spec"
```

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
- `json`

**Parameters**

* `url`: URL to be parsed/rendered _(required)_
* `refresh`: boolean to indicate that Pender should re-fetch and re-parse the URL if it already exists in its cache _(optional)_
* `archivers`: list of archivers to target. Possible values:
  * empty: the URL will be archived in all available archivers
  * `none`: the URL will not be archived
  * string with a list of archives separated by commas: the URL will be archived only on specified archivers

**Request Example**
```bash
curl \
-H 'X-Pender-Token: <your_token>' \
-H 'Content-type: application/json' \
http://localhost:3200/api/medias.json?url=<your_url>&refresh=1
```

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
        # A list of regex that tell us when we've landed on a URL for this parser, eg facebook.com
        [<list of URL patterns>]
      end

      def ignored_urls
        # Optional method to specify disallowed URLs. We generally use this to detect
        # when we've been redirected to a dead end, like a login page.
        #
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

## Error reporting

We use Sentry for tracking exceptions in our application.

By default we unset `sentry_dsn` in the `config.yml`, which prevents
information from being reported to Sentry. If you would like to see data reported from your local machine, set `sentry_dsn` to the value provided for Pender in the Sentry app.

Additional configuration:

**In config.yml**
  * `sentry_dsn` - the secret that allows us to send information to Sentry, available in the Sentry web app. Scoped to a service (e.g. Pender)
  * `sentry_environment` - the environment reported to Sentry (e.g. dev, QA, live)
  * `sentry_traces_sample_rate` - not currently used, since we don't use Sentry for tracing. Set to 0 in config as result.

**In `02_sentry.rb`**
  * `config.excluded_exceptions` - a list of exception classes that we don't want to send to Sentry

## Observability

We use Honeycomb for monitoring information about our application. It is currently configured to suppress Honeycomb reporting when the Open Telemetry required config is unset, which we would expect in development; however it is possible to report data from your local environment to either console or remotely to Honeycomb for troubleshooting purposes.

If you would like to see data reported from your local machine, do the following:

**Local console**
1. Make sure that the `otlp_exporter` prefixed values are set in `config.yml` following `config.yml.example`. The values provided in `config.yml.example` can be used since we don't need a real API key.
1. In `lib/pender/open_telemetry_config.rb`, uncomment the line setting exporter to 'console'. Warning: this is noisy!
1. Restart the server
1. View output in local server logs

**On Honeycomb**
1. Make sure that the `otlp_exporter` prefixed values are set in `config.yml` following `config.yml.example`
1. In the config key `otel_exporter_otlp_headers`, set `x-honeycomb-team` to a Honeycomb API key for the Development environment (a sandbox where we put anything). This can be found in the [Honeycomb web interface](https://ui.honeycomb.io/meedan/environments/dev/api_keys). To track your own reported info, be sure to set the `otel_resource_attributes.developer.name` key in `config.yml` to your own name or unique identifier (e.g. `christa`). You will need this to filter information on Honeycomb.
1. Restart the server
1. See reported information in Development environment on Honeycomb

### Configuring sampling

To enable sampling for Honeycomb, set the following configuration (either in `config.yml` locally, or via environment for deployments):

* `otel_traces_sampler` to a supported sampler. See the Open Telemetry documentaiton for supported values.
* `otel_custom_sampling_rate` to an integer value. This will be used to calculate and set OTEL_TRACES_SAMPLER_ARG (1 / `<sample_rate>`) and to append sampler-related value to `OTEL_RESOURCE_ATTRIBUTES` (as `SampleRate=<sample_rate>`).

**Note**: If sampling behavior is changed in Pender, we will also need to update the behavior to match in any other application reporting to Honeycomb. More [here](https://docs.honeycomb.io/getting-data-in/opentelemetry/ruby/#sampling)

### URL Parameters Normalization

Some service providers include URL parameters for tracking purposes that can be safely removed. Pender parsers can define a list of such parameters to be removed during the URL normalization process.

To define URL parameters to be removed, a parser class should implement the `urls_parameters_to_remove` method, which returns an array of strings representing the parameters to be stripped. For example:

```ruby
def urls_parameters_to_remove
  ['ighs']
end

#### Environment overrides

Often for rake tasks or background jobs, we will either want none of the data (skip reporting) or all of the data (skip sampling). For these cases we can set specific environment variables:

* To skip reporting to Honeycomb, set `PENDER_SKIP_HONEYCOMB` to `true`
* To skip sampling data we want to report to Honeycomb, set `PENDER_SKIP_HONEYCOMB_SAMPLING` to `true`

## Credits

Meedan (hello@meedan.com)
