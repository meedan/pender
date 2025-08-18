# Pender

[Test Coverage: Overview](https://codeclimate.com/github/meedan/pender)
[Test Coverage: Issues](https://codeclimate.com/github/meedan/pender/issues)
![test](https://github.com/meedan/pender/actions/workflows/ci-test-pr.yml/badge.svg?branch=main)

Pender is a service for link parsing, archiving and rendering. It is one of the services that supports [Check](https://meedan.com/check), an open source platform for collaborative fact-checking and media annotation.

## Parsing

The url is visited, parsed and the data found is used to create a media and its attributes. The data can be obtained by API or parsing directly the HTML.

In addition to parsing any link with an oEmbed endpoint or metatags, Pender supports a few page-specific parsers.

##### You can find a list of page-specific parsers in the [Pender wiki](https://github.com/meedan/pender/wiki/Supported-Page%E2%80%90Specific-Parsers).

## Archiving

When making a request to parse a URL, you can also request that the URL be archived. Currently, we support:

* **Archive.org**
  * This archiver requires `archive_org_access_key` and `archive_org_secret_key` to be set in `config/config.yml`. Get your account keys at [archive.org](https://archive.org/account/s3.php).

* **Perma.cc**
  * This archiver requires a `perma_cc_key` to be set in `config/config.yml`. Get your account key at [perma.cc](https://perma.cc).

## Setup

To set Pender up locally:

```
git clone https://github.com/meedan/pender.git
cd pender
find -name '*.example' | while read f; do cp "$f" "${f%%.example}"; done
```

To run Pender in development mode:

```
$ docker-compose build
$ docker-compose up --abort-on-container-exit
```
Open http://localhost:3200/api-docs/index.html to access Pender API directly.

## Running tests as CI
To run the full test suite of Pender tests locally the way CI runs them:

```
bin/get_env_vars.sh
docker build . -t pender
docker compose -f docker-test.yml up pender
docker compose -f docker-test.yml exec pender test/setup-parallel
docker compose -f docker-test.yml exec pender bundle exec rake "parallel:test[3]"
docker compose -f docker-test.yml exec pender bundle exec rake "parallel:spec"
```

## Setting Cookies for Requests

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

To make requests to the API, you must set a request header with the value of the configuration option `authorization_header` – by default, this is `X-Pender-Token`. The value of that header should be the API key that you have generated using `bundle exec rake lapis:api_keys:create`, or any API key that was given to you.

##### In the wiki you'll find examples of [requests and responses](https://github.com/meedan/pender/wiki/Requests-and-Responses).

## Webhook Notification

The archiving feature uses asynchronous events. Pender can notify your application after it sends URLs for archiving.

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

### URL Parameters Normalization

Some service providers include URL parameters for tracking purposes that can be safely removed. Pender parsers can define a list of such parameters to be removed during the URL normalization process.

To define URL parameters to be removed, a parser class should implement the `urls_parameters_to_remove` method, which returns an array of strings representing the parameters to be stripped. For example:

```ruby
def urls_parameters_to_remove
  ['ighs']
end
```

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

## Error reporting

We use Sentry for tracking exceptions in our application.

By default we unset `sentry_dsn` in the `config.yml`, which prevents
information from being reported to Sentry. If you would like to see data reported from your local machine, set `sentry_dsn` to the value provided for Pender in the Sentry app.

### Additional configuration

**In config.yml**
  * `sentry_dsn` - the secret that allows us to send information to Sentry, available in the Sentry web app. Scoped to a service (e.g. Pender)
  * `sentry_environment` - the environment reported to Sentry (e.g. dev, QA, live)
  * `sentry_traces_sample_rate` - not currently used, since we don't use Sentry for tracing. Set to 0 in config as result.

**In `02_sentry.rb`**
  * `config.excluded_exceptions` - a list of exception classes that we don't want to send to Sentry

## Observability

We use Honeycomb for monitoring information about our application. It is currently configured to suppress Honeycomb reporting when the Open Telemetry required config is unset, which we would expect in development; however it is possible to report data from your local environment to either console or remotely to Honeycomb for troubleshooting purposes.

### Enable reporting of Data from your local machine
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

### Environment overrides

Often for rake tasks or background jobs, we will either want none of the data (skip reporting) or all of the data (skip sampling). For these cases we can set specific environment variables:

* To skip reporting to Honeycomb, set `PENDER_SKIP_HONEYCOMB` to `true`
* To skip sampling data we want to report to Honeycomb, set `PENDER_SKIP_HONEYCOMB_SAMPLING` to `true`

## Credits

Meedan (hello@meedan.com)
