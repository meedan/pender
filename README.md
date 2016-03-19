## Pender

A parsing and rendering service

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

### Integration

Other applications can communicate with this service (and test this communication) using the client library, which can be automatically generated.

### API

#### GET /api/medias

Get parseable data for a given URL, that can be a post or a profile, from different providers

**Parameters**

* `url`: URL to be parsed/rendered _(required)_

**Response**

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

### Credits

Meedan (hello@meedan.com)
