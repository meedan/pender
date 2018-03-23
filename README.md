## Pender

<a href="https://codeclimate.com/repos/5715585edb5e930072004cc5/feed"><img src="https://codeclimate.com/repos/5715585edb5e930072004cc5/badges/f5868b936888747f319f/gpa.svg" /></a>
[![Issue Count](https://codeclimate.com/repos/5715585edb5e930072004cc5/badges/f5868b936888747f319f/issue_count.svg)](https://codeclimate.com/repos/5715585edb5e930072004cc5/feed)
[![Test Coverage](https://codeclimate.com/repos/5715585edb5e930072004cc5/badges/f5868b936888747f319f/coverage.svg)](https://codeclimate.com/repos/5715585edb5e930072004cc5/coverage)
[![Travis](https://travis-ci.org/meedan/pender.svg?branch=develop)](https://travis-ci.org/meedan/pender/)

A parsing, archiving and rendering service.

### Current support

#### Parsers

* Twitter profiles
* Twitter posts
* YouTube profiles (users and channels)
* YouTube videos
* Facebook profiles (users and pages)
* Facebook posts (from pages and users)
* Instagram posts
* Instagram profiles
* Any link with an oEmbed endpoint
* Any other link with metatags

#### Archivers

* Screenshot
* Archive.is
* Archive.org
* Video Vault

### Installation

#### Non-Docker-based

* Configure `config/config.yml`, `config/database.yml`, `config/sidekiq.yml`, `config/initializers/errbit.rb` and `config/initializers/secret_token.rb` (check the example files)
* Run `bundle install`
* Run `bundle exec rake db:migrate`
* Create an API key: `bundle exec rake lapis:api_keys:create`
* Start the server: `rails s`
* Go to [http://localhost:3000/api](http://localhost:3000/api) and use the API key you created

You can optionally use Puma, which allows you to restart the Rails server by doing: `touch tmp/restart.txt`. In order to do that, instead of `rails s`, start the server with `bundle exec pumactl start`.

#### Docker-based

* You can also start the application on Docker by running `rake lapis:docker:run` (it will run on port 3000 and your local hostname) - you first need to create an API key after entering the container (`lapis:docker:shell`) before using the web interface

### Running the tests

* `bundle install --without nothing`
* `RAILS_ENV=test bundle exec rake db:migrate`
* `RAILS_ENV=test bundle exec rake test:coverage`

### Integration

Other applications can communicate with this service (and test this communication) using the client library, which can be automatically generated.

### API

To make requests to the API, you must set a request header with the value of the configuration option `authorization_header` - by default, this is `X-Pender-Token`. The value of that header should be the API key that you have generated using `bundle exec rake lapis:api_keys:create`, or any API key that was given to you.

#### GET /api/medias.format

Get parseable data for a given URL, that can be a post or a profile, from different providers. `format` can be one of the following, see responses below:
- `html`
- `js`
- `oembed`
- `json`

**Parameters**

* `url`: URL to be parsed/rendered _(required)_
* `refresh`: boolean to indicate that Pender should re-fetch and re-parse the URL if it already exists in its cache _(optional)_

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
    "thumbnail_url": "https://yt3.ggpht.com/-MPd3Hrn0msk/AAAAAAAAAAI/AAAAAAAAAAA/I1ftnn68v8U/s88-c-k-no/photo.jpg",
    "view_count": 29101,
    "subscriber_count": 137
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
    "message": 354, # Waiting time in seconds
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

#### DELETE|PURGE /api/medias

Clears the cache for the URL(s) passed as parameter.

**Parameters**

* `url`: URL(s) to be deleted, either as an array or a string with one URL or multiple URLs separated by a space  _(required)_

**Response**

200: Success
```json
{
  "type": "success,
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

### Rake tasks

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
* `swagger:docs:markdown`: Generate the documentation in markdown format

### How to add a new parser

* Add a new file at `app/models/concerns/media_<provider>_<type>` (example... `provider` could be `facebook` and type could be `post` or `profile`)
* Include the class in `app/models/media.rb`
* It should return at least `published_at`, `username`, `title`, `description` and `picture`
* If `type` is `item`, it should also return the `author_url` and `author_picture`
* The skeleton should look like this:

```ruby
module Media<Provider><Type>
  extend ActiveSupport::Concern

  included do
    Media.declare('<provider>_<type>', [<list of URL patterns>])
  end

  def data_from_<provider>_<type>
    # Populate `self.data` with information
    # `self.data` is a hash whose key is the attribute and the value is... the value
  end

  def <provider>_as_oembed(original_url, maxwidth, maxheight)
    # Optional method
    # Define a custom oEmbed structure for this provider
  end
end
```

### How to add a new archiver

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

### Profiling

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

### Credits

Meedan (hello@meedan.com)
