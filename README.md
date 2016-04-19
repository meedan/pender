## Pender

A parsing and rendering service.

### Current support

* Twitter profiles
* YouTube profiles (users and channels)
* Facebook profiles (users and pages)

### Installation

#### Non-Docker-based

* Configure `config/config.yml`, `config/database.yml`, `config/initializers/errbit.rb` and `config/initializers/secret_token.rb` (check the example files)
* Run `bundle install`
* Run `bundle exec rake db:migrate`
* Create an API key: `bundle exec rake lapis:api_keys:create`
* Start the server: `rails s`
* Go to [http://localhost:3000/api](http://localhost:3000/api) and use the API key you created

#### Docker-based

* You can also start the application on Docker by running `rake lapis:docker:run` (it will run on port 3000 and your local hostname) - you first need to create an API key after entering the container (`lapis:docker:shell`) before using the web interface

### Running the tests

* `bundle install --without nothing`
* `RAILS_ENV=test bundle exec rake db:migrate`
* `RAILS_ENV=test bundle exec rake test:coverage`

### Integration

Other applications can communicate with this service (and test this communication) using the client library, which can be automatically generated.

### API

#### GET /api/medias

Get parseable data for a given URL, that can be a post or a profile, from different providers

**Parameters**

* `url`: URL to be parsed/rendered _(required)_

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

### How to add a new type

* Add a new file at `app/models/concerns/media_<provider>_<type>` (example... `provider` could be `facebook` and type could be `post` or `profile`)
* Include the class in `app/models/media.rb`
* It should return at least `published_at`, `username`, `title`, `description` and `picture`
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
end 
```

### Credits

Meedan (hello@meedan.com)
