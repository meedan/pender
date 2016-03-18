## Pender

A parsing and rendering service

### Installation

#### Non-Docker-based

* Configure `config/config.yml`, `config/database.yml`, `config/initializers/errbit.rb` and `config/initializers/secret_token.rb` (check the example files)
* Run `bundle install`
* Run `bundle exec rake db:migrate`
* Create an API key: `bundle exec rake lapis:api_keys:create`
* Start the server: `rails s`
* Go to http://localhost:3000/api and use the API key you created

#### Docker-based

* You can also start the application on Docker by running `./docker/run.sh` (it will run on port 80 and your local hostname) - you first need to create an API key after entering the container (`./docker/shell.sh`) before using the web interface

### Integration

Other applications can communicate with this service (and test this communication) using the client library, which can be automatically generated.

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

### Credits

Meedan (hello@meedan.com)
